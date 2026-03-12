import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/delivery_refresh_provider.dart';
import 'core/providers/notifications_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/sync/delivery_bootstrap_service.dart';
import 'shared/router/app_router.dart';
import 'shared/router/router_keys.dart';

// How often to automatically re-sync data in the background while online.
const _kAutoSyncInterval = Duration(minutes: 5);

class FsiCourierApp extends ConsumerWidget {
  const FsiCourierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final auth = ref.watch(authProvider);

    return MaterialApp.router(
      title: 'GDTMS V2 Mobile App',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      themeMode: auth.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00B14F)),
        useMaterial3: true,
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (BuildContext context) => const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B14F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (BuildContext context) => const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      routerConfig: router,
      builder: (context, child) => _AutoSyncListener(child: child!),
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
  bool _isSyncing = false;
  DateTime? _lastSyncAt;

  // Minimum gap between syncs to prevent overlapping calls.
  static const _kSyncDebounce = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Trigger 1: App startup — run after first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnStartup());
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Trigger 4: App returns to foreground (e.g., courier switches back to app).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeTriggerSync(reason: 'app_resume');
    } else if (state == AppLifecycleState.paused) {
      // Stop the periodic timer while the app is in the background.
      _periodicTimer?.cancel();
    } else if (state == AppLifecycleState.detached) {
      _periodicTimer?.cancel();
    }
  }

  void _checkOnStartup() {
    if (!mounted) return;
    if (!ref.read(authProvider).isAuthenticated) return;
    if (ref.read(isOnlineProvider)) {
      _maybeTriggerSync(reason: 'startup');
      ref.read(notificationsProvider.notifier).loadUnreadCount();
    }
  }

  void _startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_kAutoSyncInterval, (_) {
      _maybeTriggerSync(reason: 'periodic');
    });
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
    if (_lastSyncAt != null &&
        now.difference(_lastSyncAt!) < _kSyncDebounce) {
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
      await ref.read(syncManagerProvider.notifier).processQueue();

      if (!mounted) return;

      // Step 2: Pull server → SQLite (full reconcile across all statuses).
      await DeliveryBootstrapService.instance
          .syncFromApi(ref.read(apiClientProvider));

      if (mounted) {
        // Notify all listening screens (dashboard, delivery lists) to reload.
        ref.read(deliveryRefreshProvider.notifier).state++;
      }
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
        _maybeTriggerSync(reason: 'reconnected');
        _startPeriodicSync(); // Resume periodic timer once online.
        ref.read(notificationsProvider.notifier).loadUnreadCount();
      } else if (current == false) {
        _periodicTimer?.cancel(); // Pause periodic timer when offline.
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
      } else if (current.isAuthenticated == false) {
        _periodicTimer?.cancel();
      }
    });

    return widget.child;
  }
}
