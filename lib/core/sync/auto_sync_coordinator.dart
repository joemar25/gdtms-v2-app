// DOCS: docs/development-standards.md
// DOCS: docs/entry-points.md — update that file when you edit this one.
// DOCS: docs/architecture/system-map.md

// =============================================================================
// auto_sync_coordinator.dart
// =============================================================================
//
// A1: extracted from `_AutoSyncListenerState` in `lib/app.dart`.
//
// Owns sync trigger policy (startup / login / reconnect / resume / periodic),
// debounce, `_runFullSync`, the periodic timer, and delegates location-ping
// start/stop to [LocationPingService]. `app.dart`'s widget shell keeps only
// `WidgetsBindingObserver` registration and root overlay insertion — both
// tied to the widget tree, not sync policy — and calls into the entry points
// below.
//
// Trigger semantics documented in docs/entry-points.md are unchanged by this
// extraction — same 5 triggers, same debounce/skip-debounce reasons, same
// `_runFullSync` step order (requestFlush → syncFromApi → refresh).
//
// This class is tied to the provider container's lifetime (via
// [autoSyncCoordinatorProvider] + `ref.onDispose`), not a widget's — so it
// uses a `_disposed` flag (same pattern as `SyncManagerNotifier._disposed`)
// instead of a widget `mounted` check to guard state mutation and `Ref` use
// after teardown, including inside `Future.delayed` continuations that
// outlive any single trigger call.
// =============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geolocator;

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/providers/notifications_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/services/location_ping_service.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/services/push_notification_service.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/core/database/cleanup_service.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';

class AutoSyncCoordinator {
  AutoSyncCoordinator(this._ref);

  final Ref _ref;
  bool _disposed = false;

  Timer? _periodicTimer;
  final _locationPing = LocationPingService.instance;
  bool _isSyncing = false;
  DateTime? _lastSyncAt;

  // How often to automatically re-sync data in the background while online.
  static const _kAutoSyncInterval = Duration(minutes: 3);

  // Minimum gap between syncs to prevent overlapping calls.
  static const _kSyncDebounce = Duration(seconds: 30);

  /// Reasons that must flush offline backlog as soon as API is healthy
  /// (skip 30s debounce). Periodic/resume still debounced to avoid thrash.
  static const _kSkipDebounceReasons = {'reconnected', 'login'};

  void dispose() {
    _disposed = true;
    _periodicTimer?.cancel();
    _locationPing.stop();
  }

  // ── Trigger entry points ─────────────────────────────────────────────────

  /// Trigger 1: app startup — call after first frame so providers are ready.
  void onStartup() {
    if (_disposed) return;
    if (_ref.read(authProvider).isAuthenticated &&
        _ref.read(isOnlineProvider)) {
      _maybeTriggerSync(reason: 'startup');
      _locationPing.start(_sendLocationPing);
      _ref.read(notificationsProvider.notifier).loadUnreadCount();
      PushNotificationService.instance.init(_ref.read(apiClientProvider));
    }
    // Delay version check so it never blocks the splash/login flow.
    Future.delayed(const Duration(seconds: 3), () {
      if (_disposed) return;
      _ref.read(updateProvider.notifier).checkForUpdate();
    });
  }

  /// Trigger 2: fresh login while online.
  void onLogin() {
    if (_disposed) return;
    if (!_ref.read(isOnlineProvider)) return;
    _maybeTriggerSync(reason: 'login');
    _startPeriodicSync();
    _ref.read(notificationsProvider.notifier).loadUnreadCount();
    PushNotificationService.instance.init(_ref.read(apiClientProvider));
  }

  /// Logout — stop background work started for the previous session.
  void onLogout() {
    if (_disposed) return;
    _periodicTimer?.cancel();
    _locationPing.stop();
  }

  /// Trigger 3: offline → online transition.
  void onReconnect() {
    if (_disposed) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    Future.delayed(const Duration(seconds: 2), () async {
      if (_disposed) return;
      _maybeTriggerSync(reason: 'reconnected');
      _startPeriodicSync(); // Resume periodic timer once online.
      _ref.read(notificationsProvider.notifier).loadUnreadCount();
      try {
        await PushNotificationService.instance.init(
          _ref.read(apiClientProvider),
        );
      } catch (e) {
        debugPrint('[APP] Push init on reconnect failed: $e');
      }
    });
  }

  /// Online → offline transition.
  void onOffline() {
    if (_disposed) return;
    _periodicTimer?.cancel(); // Pause periodic timer when offline.
    _locationPing.stop();
  }

  /// Trigger 4: app returns to foreground.
  void onResume() {
    if (_disposed) return;
    _maybeTriggerSync(reason: 'app_resume');
    if (_ref.read(isOnlineProvider) &&
        _ref.read(authProvider).isAuthenticated) {
      _locationPing.start(_sendLocationPing);
    }
  }

  void onPause() {
    if (_disposed) return;
    _periodicTimer?.cancel();
    _locationPing.stop();
  }

  void onDetached() {
    if (_disposed) return;
    _periodicTimer?.cancel();
    _locationPing.stop();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_kAutoSyncInterval, (_) {
      _maybeTriggerSync(reason: 'periodic');
    });
    _locationPing.start(_sendLocationPing);
  }

  /// Captures the device's current GPS position and sends a background
  /// location update to the server. Errors are silently swallowed because
  /// location pings are best-effort and must never interrupt the courier flow.
  Future<void> _sendLocationPing(geolocator.Position position) async {
    if (_disposed) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    try {
      await _ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/location',
            data: {
              'latitude': position.latitude,
              'longitude': position.longitude,
              'accuracy': position.accuracy,
              'timestamp': position.timestamp.toUtc().toIso8601String(),
              'is_buffered': false,
            },
            parser: parseApiMap,
          );
      debugPrint(
        '[LOCATION] ping sent: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('[LOCATION] ping error: $e');
    }
  }

  /// Fires a sync only if:
  /// - The user is authenticated and online (network + API reachable).
  /// - Not already syncing.
  /// - Enough time has passed since the last sync (debounce), unless
  ///   [reason] is `reconnected` or `login` (offline backlog must drain).
  void _maybeTriggerSync({required String reason}) {
    if (_disposed) return;
    if (!_ref.read(authProvider).isAuthenticated) return;
    if (!_ref.read(isOnlineProvider)) return;
    if (_isSyncing) return;

    final now = DateTime.now();
    final skipDebounce = _kSkipDebounceReasons.contains(reason);
    if (!skipDebounce &&
        _lastSyncAt != null &&
        now.difference(_lastSyncAt!) < _kSyncDebounce) {
      return;
    }

    _isSyncing = true;
    _lastSyncAt = now;

    // ignore: discarded_futures
    _runFullSync(reason: reason);
  }

  /// Sequential full sync (same order as pre-A8 production behavior):
  ///
  /// Step 1 — Push dirty offline queue entries to the server first.
  /// Step 2 — Pull server statuses and reconcile with SQLite.
  ///
  /// Only concurrency/coalescing of the queue flush changed — not
  /// reconciliation Rules 1–4, not which statuses sync, not debounce
  /// intervals (except reconnect/login skip debounce so API recovery
  /// flushes backlog promptly).
  Future<void> _runFullSync({required String reason}) async {
    try {
      debugPrint('[SYNC] _runFullSync start reason=$reason');
      // Step 1: Coalesced queue flush. Joins any in-flight UI submit flush and
      // re-runs if items were enqueued mid-pass.
      await _ref
          .read(syncManagerProvider.notifier)
          .requestFlush(reason: 'auto_sync_$reason', awaitIdle: true);

      debugPrint(
        '[SYNC] _runFullSync: after requestFlush reason=$reason '
        'disposed=$_disposed',
      );
      if (_disposed) return;

      // If API dropped mid-flush, do not start bootstrap pull (burns errors and
      // can race a dying server). Queue leftovers retry on next online trigger.
      if (!_ref.read(isOnlineProvider)) {
        debugPrint(
          '[SYNC] _runFullSync: abort pull — API no longer online '
          'reason=$reason',
        );
        return;
      }

      // Step 2: Pull server → SQLite (full reconcile across all statuses).
      await DeliveryBootstrapService.instance.syncFromApi(
        _ref.read(apiClientProvider),
      );

      debugPrint(
        '[SYNC] _runFullSync: after syncFromApi reason=$reason '
        'disposed=$_disposed',
      );
      if (!_disposed) {
        final now = DateTime.now();
        _ref.read(lastSyncTimeProvider.notifier).setValue(now);
        _ref
            .read(authStorageProvider)
            .setLastSyncTime(now.millisecondsSinceEpoch);

        // Notify all listening screens (dashboard, delivery lists) to reload.
        final prev = _ref.read(deliveryRefreshProvider);
        _ref.read(deliveryRefreshProvider.notifier).increment();
        debugPrint('[SYNC] deliveryRefreshProvider: $prev → ${prev + 1}');
      }

      // Automatically clean up old data after successful sync
      await CleanupService.instance.runIfNeeded(_ref.read(appSettingsProvider));
    } catch (e) {
      debugPrint('[SYNC] _runFullSync ERROR reason=$reason: $e');
    } finally {
      if (!_disposed) _isSyncing = false;
    }
  }
}

final autoSyncCoordinatorProvider = Provider<AutoSyncCoordinator>((ref) {
  final coordinator = AutoSyncCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
