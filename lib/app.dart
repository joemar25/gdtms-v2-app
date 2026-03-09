import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/sync/delivery_bootstrap_service.dart';
import 'shared/router/app_router.dart';
import 'shared/router/router_keys.dart';

class FsiCourierApp extends ConsumerWidget {
  const FsiCourierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final auth = ref.watch(authProvider);

    return MaterialApp.router(
      title: 'FSI Courier',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      themeMode: auth.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00B14F)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B14F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
      builder: (context, child) => _ExitGuard(
        child: _AutoSyncListener(child: child!),
      ),
    );
  }
}

/// Listens for the device coming back online and triggers both the delivery
/// bootstrap (seeding SQLite from the API) and the offline sync queue.
/// Placed at the root widget level so it stays alive for the entire app lifecycle.
class _AutoSyncListener extends ConsumerStatefulWidget {
  const _AutoSyncListener({required this.child});
  final Widget child;

  @override
  ConsumerState<_AutoSyncListener> createState() =>
      _AutoSyncListenerState();
}

class _AutoSyncListenerState extends ConsumerState<_AutoSyncListener> {
  @override
  void initState() {
    super.initState();
    // Run bootstrap once on startup if the device is already online.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnStartup());
  }

  void _checkOnStartup() {
    if (!mounted) return;
    // Don't run before the auth state has been loaded from secure storage.
    if (!ref.read(authProvider).isAuthenticated) return;
    final isOnline = ref.read(isOnlineProvider);
    if (isOnline) _triggerBootstrapAndSync();
  }

  void _triggerBootstrapAndSync() {
    // Fire-and-forget — bootstrap is best-effort, never blocks the UI.
    DeliveryBootstrapService.instance
        .syncFromApi(ref.read(apiClientProvider));
    final syncState = ref.read(syncManagerProvider);
    if (!syncState.isSyncing) {
      ref.read(syncManagerProvider.notifier).processQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isOnlineProvider, (previous, current) {
      // Only trigger when transitioning from offline → online.
      if (previous == false && current == true) {
        _triggerBootstrapAndSync();
      }
    });

    // Bootstrap also fires on fresh login (unauthenticated → authenticated).
    ref.listen<AuthState>(authProvider, (previous, current) {
      if (previous?.isAuthenticated == false &&
          current.isAuthenticated == true &&
          ref.read(isOnlineProvider)) {
        _triggerBootstrapAndSync();
      }
    });

    return widget.child;
  }
}

/// Intercepts the system back gesture/button on the root route and asks the
/// user to confirm before exiting the app.
class _ExitGuard extends StatelessWidget {
  const _ExitGuard({required this.child});
  final Widget child;

  Future<void> _onPopInvoked(BuildContext context, bool didPop) async {
    if (didPop) return;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'YES, EXIT',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(context, didPop),
      child: child,
    );
  }
}
