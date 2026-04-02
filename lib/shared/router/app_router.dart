import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/providers/location_provider.dart';
import 'package:fsi_courier_app/features/location/location_required_screen.dart';
import 'package:fsi_courier_app/features/auth/login_screen.dart';
import 'package:fsi_courier_app/features/auth/reset_password_screen.dart';
import 'package:fsi_courier_app/splash_screen.dart';
import 'package:fsi_courier_app/features/dashboard/dashboard_screen.dart';
import 'package:fsi_courier_app/features/delivery/delivery_detail_screen.dart';
import 'package:fsi_courier_app/features/delivery/delivery_status_list_screen.dart';
import 'package:fsi_courier_app/features/delivery/delivery_update_screen.dart';
import 'package:fsi_courier_app/features/dispatch/dispatch_eligibility_screen.dart';
import 'package:fsi_courier_app/features/dispatch/dispatch_list_screen.dart';
import 'package:fsi_courier_app/features/profile/profile_screen.dart';
import 'package:fsi_courier_app/features/scan/scan_screen.dart';
import 'package:fsi_courier_app/features/wallet/payout_detail_screen.dart';
import 'package:fsi_courier_app/features/wallet/payout_request_screen.dart';
import 'package:fsi_courier_app/features/sync/sync_screen.dart';
import 'package:fsi_courier_app/features/wallet/wallet_screen.dart';
import 'package:fsi_courier_app/features/initial_sync/initial_sync_screen.dart';
import 'package:fsi_courier_app/features/error_logs/error_logs_screen.dart';
import 'package:fsi_courier_app/features/notifications/notifications_screen.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';

final initialLocationProvider = Provider<String>((ref) => '/splash');

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen<LocationState>(locationProvider, (_, __) => notifyListeners());
  }
}

// ── Transition helper ─────────────────────────────────────────────────────────

/// Builds a [CustomTransitionPage] with a smooth fade + subtle upward-slide.
/// All app routes use this for a consistent, polished feel.
Page<T> _page<T>({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = Tween<Offset>(
        begin: const Offset(0.0, 0.035),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

// ── Router ────────────────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final locationState = ref.read(locationProvider);

      final path = state.uri.path;
      final isAuthRoute =
          path == '/login' ||
          path == '/reset-password' ||
          path == '/splash';

      // Allow unauthenticated users to access auth routes
      if (!auth.isAuthenticated) {
        if (!isAuthRoute) return '/login';
        return null;
      }

      // ── GLOBAL GEOLOCATION GUARD ──
      final isUpdateRoute = path.contains('/update');
      if (path != '/splash' && !isUpdateRoute) {
        if (!locationState.isReady) {
          if (path != '/location-required') {
            return '/location-required';
          }
          return null;
        } else if (path == '/location-required' && locationState.isReady) {
          return '/dashboard';
        }
      }

      if (auth.isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }

      // ── INITIAL SYNC GUARD ──
      if (!auth.initialSyncCompleted && path != '/initial-sync') {
        return '/initial-sync';
      }
      if (auth.initialSyncCompleted && path == '/initial-sync') {
        return '/dashboard';
      }

      if (path == '/') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => _page(key: state.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/initial-sync',
        pageBuilder: (_, state) => _page(key: state.pageKey, child: const InitialSyncScreen()),
      ),
      GoRoute(
        path: '/location-required',
        pageBuilder: (_, state) => _page(key: state.pageKey, child: const LocationRequiredScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _page(key: state.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const ResetPasswordScreen(authenticatedMode: false),
        ),
      ),
      GoRoute(
        path: '/change-password',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const ResetPasswordScreen(authenticatedMode: true),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (_, state) => _page(key: state.pageKey, child: const DashboardScreen()),
      ),

      // ── Unified scan ──────────────────────────────────────────────────────
      GoRoute(
        path: '/scan',
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final isDispatch = extra['mode'] == 'dispatch';
          final mode = isDispatch ? ScanMode.dispatch : ScanMode.pod;
          return _page(key: state.pageKey, child: ScanScreen(mode: mode));
        },
      ),

      GoRoute(
        path: '/dispatches',
        pageBuilder: (_, state) =>
            _page(key: state.pageKey, child: const DispatchListScreen()),
      ),
      GoRoute(
        path: '/dispatches/eligibility',
        pageBuilder: (_, state) {
          final extra = asStringDynamicMap(state.extra);
          final parsedResponse = asStringDynamicMap(extra['eligibility_response']);
          final response = parsedResponse.isNotEmpty
              ? parsedResponse
              : {'eligible': false, 'message': 'Eligibility data missing.'};
          return _page(
            key: state.pageKey,
            child: DispatchEligibilityScreen(
              dispatchCode: (extra['dispatch_code'] ??
                      state.uri.queryParameters['dispatch_code'] ??
                      '')
                  .toString(),
              eligibilityResponse: response,
              autoAccept: extra['auto_accept'] == true,
              skipPinDialog: extra['skip_accept_modal'] == true,
              showFullCode: extra['show_full_code'] == true,
            ),
          );
        },
      ),
      GoRoute(
        path: '/deliveries',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const DeliveryStatusListScreen(status: 'pending', title: 'DELIVERIES'),
        ),
      ),
      GoRoute(
        path: '/deliveries/:barcode',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: DeliveryDetailScreen(barcode: state.pathParameters['barcode']!),
        ),
      ),
      GoRoute(
        path: '/deliveries/:barcode/update',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: DeliveryUpdateScreen(barcode: state.pathParameters['barcode']!),
        ),
      ),
      GoRoute(
        path: '/delivered',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const DeliveryStatusListScreen(status: 'delivered', title: 'DELIVERED'),
        ),
      ),
      GoRoute(
        path: '/rts',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const DeliveryStatusListScreen(status: 'rts', title: 'RTS'),
        ),
      ),
      GoRoute(
        path: '/osa',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const DeliveryStatusListScreen(status: 'osa', title: 'OSA'),
        ),
      ),
      GoRoute(
        path: '/sync',
        pageBuilder: (_, state) => _page(key: state.pageKey, child: const SyncScreen()),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, state) =>
            _page(key: state.pageKey, child: const NotificationsScreen()),
      ),
      GoRoute(
        path: '/wallet',
        pageBuilder: (_, state) => _page(key: state.pageKey, child: const WalletScreen()),
      ),
      GoRoute(
        path: '/wallet/request',
        pageBuilder: (_, state) {
          final extra = state.extra;
          return _page(
            key: state.pageKey,
            child: PayoutRequestScreen(
              isConsolidation: extra is Map && extra['consolidate'] == true,
            ),
          );
        },
      ),
      GoRoute(
        path: '/wallet/:reference',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: PayoutDetailScreen(reference: state.pathParameters['reference'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, state) => _page(key: state.pageKey, child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/error-logs',
        pageBuilder: (_, state) => _page(key: state.pageKey, child: const ErrorLogsScreen()),
      ),
    ],
  );
});
