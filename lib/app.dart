// DOCS: docs/development-standards.md
// DOCS: docs/entry-points.md — update that file when you edit this one.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geolocator;

import 'core/api/api_client.dart';
import 'shared/helpers/api_payload_helper.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/auth_storage.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/delivery_refresh_provider.dart';
import 'core/providers/notifications_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/services/location_ping_service.dart';
import 'core/settings/app_settings.dart';
import 'core/services/push_notification_service.dart';
import 'core/sync/delivery_bootstrap_service.dart';
import 'core/database/cleanup_service.dart';
import 'shared/router/app_router.dart';
import 'shared/router/router_keys.dart';
import 'shared/widgets/time_enforcer.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// How often to automatically re-sync data in the background while online.
const _kAutoSyncInterval = Duration(minutes: 3);

class FsiCourierApp extends ConsumerWidget {
  const FsiCourierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cap the image cache: 80 MB / 150 images max.
    // Default Flutter limits (unlimited count, 100 MB) are too generous for a
    // delivery app that shows many thumbnails on list screens.
    PaintingBinding.instance.imageCache
      ..maximumSize = 150
      ..maximumSizeBytes = 80 << 20; // 80 MB

    final router = ref.watch(appRouterProvider);
    final auth = ref.watch(authProvider);

    return MaterialApp.router(
      title: 'GDTMS V2 Mobile App',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      themeMode: auth.themeMode,
      theme: DSTheme.build(Brightness.light),
      darkTheme: DSTheme.build(Brightness.dark),
      routerConfig: router,
      builder: (context, child) =>
          TimeEnforcer(child: _AutoSyncListener(child: child!)),
    );
  }
}

/// Keeps data accurate for average users by syncing in multiple scenarios:
///
/// 1. **App startup** — runs immediately if the device is already online.
/// 2. **Login** — runs after a fresh login while online.
/// 3. **Offline → Online** — runs as soon as the device regains connectivity.
/// 4. **App resume** — runs when the courier switches back to this app from
///    another app (e.g., they checked messages and came back). This is the
///    most common trigger for delivery couriers during their working day.
/// 5. **Periodic** — runs every [_kAutoSyncInterval] minutes while the app
///    is in the foreground and online, so data never goes stale mid-shift.
///
/// All syncs are fire-and-forget and use debouncing to prevent overlapping calls.
class _AutoSyncListener extends ConsumerStatefulWidget {
  const _AutoSyncListener({required this.child});
  final Widget child;

  @override
  ConsumerState<_AutoSyncListener> createState() => _AutoSyncListenerState();
}

class _AutoSyncListenerState extends ConsumerState<_AutoSyncListener>
    with WidgetsBindingObserver {
  Timer? _periodicTimer;
  final _locationPing = LocationPingService.instance;
  bool _isSyncing = false;
  DateTime? _lastSyncAt;
  OverlayEntry? _syncPillEntry;

  // Minimum gap between syncs to prevent overlapping calls.
  static const _kSyncDebounce = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trigger 1: App startup — run after first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnStartup();
      _insertSyncPill();
    });
  }

  void _insertSyncPill() {
    if (_syncPillEntry != null) return;
    _syncPillEntry = OverlayEntry(
      builder: (_) => const RepaintBoundary(child: _SyncFloatingPill()),
    );
    rootNavigatorKey.currentState?.overlay?.insert(_syncPillEntry!);
  }

  @override
  void dispose() {
    _syncPillEntry?.remove();
    _syncPillEntry = null;
    _periodicTimer?.cancel();
    _locationPing.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Trigger 4: App returns to foreground (e.g., courier switches back to app).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeTriggerSync(reason: 'app_resume');
      if (ref.read(isOnlineProvider) &&
          ref.read(authProvider).isAuthenticated) {
        _locationPing.start(_sendLocationPing);
      }
    } else if (state == AppLifecycleState.paused) {
      // Stop background services while app is not visible.
      _periodicTimer?.cancel();
      _locationPing.stop();
    } else if (state == AppLifecycleState.detached) {
      _periodicTimer?.cancel();
      _locationPing.stop();
    }
  }

  void _checkOnStartup() {
    if (!mounted) return;
    if (!ref.read(authProvider).isAuthenticated) return;
    if (ref.read(isOnlineProvider)) {
      _maybeTriggerSync(reason: 'startup');
      _locationPing.start(_sendLocationPing);
      ref.read(notificationsProvider.notifier).loadUnreadCount();
      PushNotificationService.instance.init(ref.read(apiClientProvider));
    }
  }

  void _startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_kAutoSyncInterval, (_) {
      _maybeTriggerSync(reason: 'periodic');
    });
    _locationPing.start(_sendLocationPing);
  }

  /// Captures the device's current GPS position and sends a background
  /// location update to the server.  Errors are silently swallowed because
  /// location pings are best-effort and must never interrupt the courier flow.
  Future<void> _sendLocationPing(geolocator.Position position) async {
    if (!mounted) return;
    if (!ref.read(authProvider).isAuthenticated) return;
    try {
      await ref
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
  /// - The user is authenticated and online.
  /// - Not already syncing.
  /// - Enough time has passed since the last sync (debounce).
  void _maybeTriggerSync({required String reason}) {
    if (!mounted) return;
    if (!ref.read(authProvider).isAuthenticated) return;
    if (!ref.read(isOnlineProvider)) return;
    if (_isSyncing) return;

    final now = DateTime.now();
    if (_lastSyncAt != null && now.difference(_lastSyncAt!) < _kSyncDebounce) {
      return;
    }

    _isSyncing = true;
    _lastSyncAt = now;

    // ignore: discarded_futures
    _runFullSync();
  }

  /// Sequential full sync:
  ///
  /// Step 1 — Push dirty offline queue entries to the server first.
  ///   The server must have the courier's latest offline updates before we
  ///   pull from it, otherwise bootstrap would fetch stale server state.
  ///
  /// Step 2 — Pull all server statuses (pending / delivered / rts / osa)
  ///   and reconcile with SQLite. Because the queue is now drained, the
  ///   server reflects the courier's true current state, making this pull
  ///   authoritative.
  ///
  /// deliveryRefreshProvider is incremented:
  ///   • by processQueue() itself when entries succeed (early UI refresh), and
  ///   • once more after bootstrap completes (final authoritative refresh).
  Future<void> _runFullSync() async {
    try {
      // Step 1: Flush dirty queue → server.
      // processQueue() skips immediately when isSyncing=true (a fire-and-forget
      // call from delivery_update_screen may already be running). Wait for it
      // to finish so syncFromApi always sees a fully drained queue.
      await ref.read(syncManagerProvider.notifier).processQueue();
      await ref.read(syncManagerProvider.notifier).waitUntilIdle();

      debugPrint('[SYNC] _runFullSync: after processQueue, mounted=$mounted');
      if (!mounted) return;

      // Step 2: Pull server → SQLite (full reconcile across all statuses).
      await DeliveryBootstrapService.instance.syncFromApi(
        ref.read(apiClientProvider),
      );

      debugPrint('[SYNC] _runFullSync: after syncFromApi, mounted=$mounted');
      if (mounted) {
        final now = DateTime.now();
        ref.read(lastSyncTimeProvider.notifier).setValue(now);
        ref
            .read(authStorageProvider)
            .setLastSyncTime(now.millisecondsSinceEpoch);

        // Notify all listening screens (dashboard, delivery lists) to reload.
        final prev = ref.read(deliveryRefreshProvider);
        ref.read(deliveryRefreshProvider.notifier).increment();
        debugPrint('[SYNC] deliveryRefreshProvider: $prev → ${prev + 1}');
      }

      // Automatically clean up old data after successful sync
      await CleanupService.instance.runIfNeeded(ref.read(appSettingsProvider));
    } catch (e) {
      debugPrint('[SYNC] _runFullSync ERROR: $e');
    } finally {
      if (mounted) _isSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trigger 3: Offline → Online transition.
    ref.listen<bool>(isOnlineProvider, (previous, current) {
      if (previous == false && current == true) {
        if (!ref.read(authProvider).isAuthenticated) return;
        Future.delayed(const Duration(seconds: 2), () async {
          if (!mounted) return;
          _maybeTriggerSync(reason: 'reconnected');
          _startPeriodicSync(); // Resume periodic timer once online.
          ref.read(notificationsProvider.notifier).loadUnreadCount();
          try {
            await PushNotificationService.instance.init(
              ref.read(apiClientProvider),
            );
          } catch (e) {
            debugPrint('[APP] Push init on reconnect failed: $e');
          }
        });
      } else if (current == false) {
        _periodicTimer?.cancel(); // Pause periodic timer when offline.
        _locationPing.stop();
      }
    });

    // Trigger 2: Fresh login.
    ref.listen<AuthState>(authProvider, (previous, current) {
      if (previous?.isAuthenticated == false &&
          current.isAuthenticated == true &&
          ref.read(isOnlineProvider)) {
        _maybeTriggerSync(reason: 'login');
        _startPeriodicSync();
        ref.read(notificationsProvider.notifier).loadUnreadCount();
        PushNotificationService.instance.init(ref.read(apiClientProvider));
      } else if (current.isAuthenticated == false) {
        _periodicTimer?.cancel();
        _locationPing.stop();
      }
    });

    return widget.child;
  }
}

// ── Global Sync Floating Pill ─────────────────────────────────────────────────
//
// Inserted as a root OverlayEntry so it floats above all screens without
// affecting any layout. Returns an invisible widget when nothing is pending.

// Routes on which the pill should never appear.
const _kPillHiddenRoutes = {
  '/sync',
  '/splash',
  '/login',
  '/reset-password',
  '/location-required', // also covers camera + notification permission screens
};

class _SyncFloatingPill extends ConsumerWidget {
  const _SyncFloatingPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(authProvider).isAuthenticated) {
      return const SizedBox.shrink();
    }

    final router = ref.watch(appRouterProvider);
    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routeInformationProvider.value.uri.path;
        if (_kPillHiddenRoutes.contains(path)) {
          return const SizedBox.shrink();
        }
        return const _SyncPillContent();
      },
    );
  }
}

class _SyncPillContent extends ConsumerWidget {
  const _SyncPillContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // select() extracts only the display values — prevents rebuilds when
    // unrelated SyncState fields change (e.g. a different entry's retry count).
    final (
      :isSyncing,
      :pending,
      :failed,
      :lastMessage,
      :total,
      :processed,
    ) = ref.watch(
      syncManagerProvider.select((s) {
        final p = s.entries
            .where((e) => e.status == 'pending' || e.status == 'processing')
            .length;
        final f = s.entries
            .where(
              (e) =>
                  e.status == 'error' ||
                  e.status == 'failed' ||
                  e.status == 'conflict',
            )
            .length;
        return (
          isSyncing: s.isSyncing,
          pending: p,
          failed: f,
          lastMessage: s.lastMessage,
          total: s.total,
          processed: s.processed,
        );
      }),
    );
    final isOnline = ref.watch(isOnlineProvider);

    final hasActivity = isSyncing || pending > 0 || failed > 0;
    final top = MediaQuery.of(context).padding.top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedOpacity(
      opacity: hasActivity ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 280),
      child: IgnorePointer(
        ignoring: !hasActivity,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              DSSpacing.md,
              top + DSSpacing.sm,
              DSSpacing.md,
              0,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: Material(
                color: DSColors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? DSColors.cardElevatedDark.withValues(
                            alpha: DSStyles.alphaOpaque,
                          )
                        : DSColors.white.withValues(
                            alpha: DSStyles.alphaOpaque,
                          ),
                    borderRadius: DSStyles.circularRadius,
                    boxShadow: DSStyles.shadowXS(context),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSyncing) ...[
                        const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: DSStyles.strokeWidth,
                          ),
                        ),
                        DSSpacing.wSm,
                        Flexible(
                          child: Text(
                            _trimMessage(lastMessage ?? 'Syncing…'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (total > 0) ...[
                          DSSpacing.wSm,
                          Text(
                            '$processed/$total',
                            style: DSTypography.label(
                              color: isDark
                                  ? DSColors.labelSecondaryDark
                                  : DSColors.labelSecondary,
                            ).copyWith(fontSize: DSTypography.sizeXs),
                          ),
                        ],
                      ] else ...[
                        Icon(
                          isOnline
                              ? Icons.cloud_sync_outlined
                              : Icons.cloud_off_outlined,
                          size: DSIconSize.xs,
                          color: failed > 0
                              ? DSColors.error
                              : (isDark
                                    ? DSColors.labelSecondaryDark
                                    : DSColors.labelSecondary),
                        ),
                        DSSpacing.wSm,
                        Text(
                          [
                            if (pending > 0) '$pending pending',
                            if (failed > 0) '$failed failed',
                          ].join(' · '),
                          style: DSTypography.caption(
                            color: failed > 0 ? DSColors.error : null,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Strips the barcode from long sync messages so the pill stays compact.
  /// e.g. "Updating delivery B132256VI150 to server…" → "Updating delivery…"
  static String _trimMessage(String msg) {
    // Remove anything that looks like a barcode (all-caps alphanumeric 8+ chars)
    return msg
        .replaceAll(RegExp(r'\b[A-Z0-9]{8,}\b'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}
