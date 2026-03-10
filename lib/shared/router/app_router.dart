import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
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
import 'package:fsi_courier_app/features/notifications/notifications_screen.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';

final initialLocationProvider = Provider<String>((ref) => '/splash');

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      final isAuthRoute =
          path == '/login' ||
          path == '/reset-password' ||
          path == '/splash';

      if (!auth.isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      if (auth.isAuthenticated && isAuthRoute) {
        return '/dashboard';
      }

      if (path == '/') return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen(),
      ),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),

      // ── Unified scan (replaces /dispatches/scan and /deliveries/scan) ──
      GoRoute(
        path: '/scan',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final isDispatch = extra['mode'] == 'dispatch';
          final mode = isDispatch ? ScanMode.dispatch : ScanMode.pod;
          return ScanScreen(
            mode: mode,
          );
        },
      ),

      GoRoute(
        path: '/dispatches',
        builder: (_, __) => const DispatchListScreen(),
      ),
      GoRoute(
        path: '/dispatches/eligibility',
        builder: (_, state) {
          final extra = asStringDynamicMap(state.extra);
          final parsedResponse = asStringDynamicMap(
            extra['eligibility_response'],
          );
          final response = parsedResponse.isNotEmpty
              ? parsedResponse
              : {'eligible': false, 'message': 'Eligibility data missing.'};
          return DispatchEligibilityScreen(
            dispatchCode:
                (extra['dispatch_code'] ??
                        state.uri.queryParameters['dispatch_code'] ??
                        '')
                    .toString(),
            eligibilityResponse: response,
            autoAccept: extra['auto_accept'] == true,
            skipPinDialog: extra['skip_accept_modal'] == true,
            showFullCode: extra['show_full_code'] == true,
          );
        },
      ),
      GoRoute(
        path: '/deliveries',
        builder: (_, __) => const DeliveryStatusListScreen(
          status: 'pending',
          title: 'DELIVERIES',
        ),
      ),
      GoRoute(
        path: '/deliveries/:barcode',
        builder: (_, state) =>
            DeliveryDetailScreen(barcode: state.pathParameters['barcode']!),
      ),
      GoRoute(
        path: '/deliveries/:barcode/update',
        builder: (_, state) =>
            DeliveryUpdateScreen(barcode: state.pathParameters['barcode']!),
      ),
      GoRoute(
        path: '/delivered',
        builder: (_, __) => const DeliveryStatusListScreen(
          status: 'delivered',
          title: 'DELIVERED',
        ),
      ),
      GoRoute(
        path: '/rts',
        builder: (_, __) => const DeliveryStatusListScreen(
          status: 'rts',
          title: 'RTS',
        ),
      ),
      GoRoute(
        path: '/osa',
        builder: (_, __) => const DeliveryStatusListScreen(
          status: 'osa',
          title: 'OSA',
        ),
      ),
      GoRoute(path: '/history', builder: (_, __) => const SyncScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
      GoRoute(
        path: '/wallet/request',
        builder: (_, __) => const PayoutRequestScreen(),
      ),
      GoRoute(
        path: '/wallet/:reference',
        builder: (_, state) => PayoutDetailScreen(
          reference: state.pathParameters['reference'] ?? '',
        ),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
});
