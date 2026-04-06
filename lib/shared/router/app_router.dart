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
import 'package:fsi_courier_app/features/profile/profile_edit_screen.dart';
import 'package:fsi_courier_app/features/scan/scan_screen.dart';
import 'package:fsi_courier_app/features/wallet/payout_detail_screen.dart';
import 'package:fsi_courier_app/features/wallet/payout_request_screen.dart';
import 'package:fsi_courier_app/features/sync/sync_screen.dart';
import 'package:fsi_courier_app/features/wallet/wallet_screen.dart';
import 'package:fsi_courier_app/features/initial_sync/initial_sync_screen.dart';
import 'package:fsi_courier_app/features/error_logs/error_logs_screen.dart';
import 'package:fsi_courier_app/features/notifications/notifications_screen.dart';
import 'package:fsi_courier_app/features/legal/terms_screen.dart';
import 'package:fsi_courier_app/features/legal/privacy_screen.dart';
import 'package:fsi_courier_app/features/report/report_issue_screen.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';
import 'package:fsi_courier_app/shared/widgets/bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

final initialLocationProvider = Provider<String>((ref) => '/splash');

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
    ref.listen<LocationState>(locationProvider, (_, _) => notifyListeners());
  }
}

// ── Transition helpers ───────────────────────────────────────────────────────

/// Builds a [CustomTransitionPage] with a smooth fade + full horizontal slide.
/// Designed specifically for bottom-nav transitions.
Page<T> _tabTransitionPage<T>({required LocalKey key, required Widget child}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));

      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

/// Builds a [CustomTransitionPage] for secondary screens (pushed routes).
/// Uses a prominent horizontal slide from the right.
Page<T> _page<T>({
  required LocalKey key,
  required Widget child,
  Object? extra,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // If the route was navigated with an extra indicating a swipe direction,
      // perform a horizontal slide that matches the swipe (left/right).
      String? swipeDir;
      if (extra is Map) {
        final val = extra['_swipe'];
        if (val is String) swipeDir = val;
      }

      final Offset begin;
      if (swipeDir == 'right') {
        begin = const Offset(-1.0, 0.0); // coming from the left
      } else {
        begin = const Offset(1.0, 0.0); // default: slide in from the right
      }

      final slide = Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
        ),
      );
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

// ── Persistent Layout Wrapper ───────────────────────────────────────────────

class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  int _previousIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final isForward = currentIndex >= _previousIndex;

    // Capture direction BEFORE rebuilding so the transition builder can read it.
    if (currentIndex != _previousIndex) {
      // Will be reset after build.
      Future.microtask(() {
        if (mounted) setState(() => _previousIndex = currentIndex);
      });
    }

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        reverseDuration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutQuart,
        switchOutCurve: Curves.easeInQuart,
        transitionBuilder: (child, animation) {
          // Slide direction depends on whether we're going to a higher or lower index.
          final slideIn = Tween<Offset>(
            begin: Offset(isForward ? 1.0 : -1.0, 0.0),
            end: Offset.zero,
          ).animate(animation);
          final slideOut = Tween<Offset>(
            begin: Offset.zero,
            end: Offset(isForward ? -0.3 : 0.3, 0.0),
          ).animate(animation);

          // The 'child' in transitionBuilder is either the new or the old widget.
          // We slide the incoming page in and the outgoing page out slightly.
          final isIncoming =
              (child.key as ValueKey<int>?)?.value == currentIndex;
          return SlideTransition(
            position: isIncoming ? slideIn : slideOut,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(currentIndex),
          child: widget.navigationShell,
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        navigationShell: widget.navigationShell,
      ),
    );
  }
}

// ── Router ────────────────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: notifier,
    redirect: (context, state) async {
      final auth = ref.read(authProvider);
      final locationState = ref.read(locationProvider);

      final path = state.uri.path;
      final isAuthRoute =
          path == '/login' || path == '/reset-password' || path == '/splash';
      final isLegalRoute = path == '/terms' || path == '/privacy';

      // Allow unauthenticated users to access auth routes
      if (!auth.isAuthenticated) {
        if (!isAuthRoute) return '/login';
        return null;
      }

      // ── TERMS & CONDITIONS GATE ──
      // After auth, before anything else: ensure the courier has accepted T&C.
      if (!isLegalRoute && !isAuthRoute) {
        final prefs = await SharedPreferences.getInstance();
        final accepted = prefs.getString('terms_accepted_version');
        if (accepted != kTermsVersion) return '/terms';
      }

      // ── GLOBAL GEOLOCATION GUARD ──
      final isUpdateRoute = path.contains('/update');
      if (path != '/splash' && !isUpdateRoute && !isLegalRoute) {
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
      if (!auth.initialSyncCompleted &&
          path != '/initial-sync' &&
          !isLegalRoute) {
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
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const SplashScreen(),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/initial-sync',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const InitialSyncScreen(),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/location-required',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const LocationRequiredScreen(),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const LoginScreen(),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const ResetPasswordScreen(authenticatedMode: false),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/change-password',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const ResetPasswordScreen(authenticatedMode: true),
          extra: state.extra,
        ),
      ),
      // ── Main Shell (Persistent Tabs) ───────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (_, state) => _tabTransitionPage(
                  key: state.pageKey,
                  child: const DashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                pageBuilder: (_, state) => _tabTransitionPage(
                  key: state.pageKey,
                  child: const WalletScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (_, state) => _tabTransitionPage(
                  key: state.pageKey,
                  child: const ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Unified scan ──────────────────────────────────────────────────────
      GoRoute(
        path: '/scan',
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final isDispatch = extra['mode'] == 'dispatch';
          final mode = isDispatch ? ScanMode.dispatch : ScanMode.pod;
          return _page(
            key: state.pageKey,
            child: ScanScreen(mode: mode),
            extra: state.extra,
          );
        },
      ),

      GoRoute(
        path: '/dispatches',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const DispatchListScreen(),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/dispatches/eligibility',
        pageBuilder: (_, state) {
          final extra = asStringDynamicMap(state.extra);
          final parsedResponse = asStringDynamicMap(
            extra['eligibility_response'],
          );
          final response = parsedResponse.isNotEmpty
              ? parsedResponse
              : {'eligible': false, 'message': 'Eligibility data missing.'};
          return _page(
            key: state.pageKey,
            child: DispatchEligibilityScreen(
              dispatchCode:
                  (extra['dispatch_code'] ??
                          state.uri.queryParameters['dispatch_code'] ??
                          '')
                      .toString(),
              eligibilityResponse: response,
              autoAccept: extra['auto_accept'] == true,
              skipPinDialog: extra['skip_accept_modal'] == true,
              showFullCode: extra['show_full_code'] == true,
            ),
            extra: state.extra,
          );
        },
      ),
      GoRoute(
        path: '/deliveries',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const DeliveryStatusListScreen(
            status: 'pending',
            title: 'DELIVERIES',
          ),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/deliveries/:barcode',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: DeliveryDetailScreen(
            barcode: state.pathParameters['barcode']!,
          ),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/deliveries/:barcode/update',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: DeliveryUpdateScreen(
            barcode: state.pathParameters['barcode']!,
          ),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/delivered',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const DeliveryStatusListScreen(
            status: 'delivered',
            title: 'DELIVERED',
          ),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/rts',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const DeliveryStatusListScreen(status: 'rts', title: 'RTS'),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/osa',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const DeliveryStatusListScreen(status: 'osa', title: 'OSA'),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/sync',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const SyncScreen(),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const NotificationsScreen(),
          extra: state.extra,
        ),
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
            extra: state.extra,
          );
        },
      ),
      GoRoute(
        path: '/wallet/:reference',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: PayoutDetailScreen(
            reference: state.pathParameters['reference'] ?? '',
          ),
          extra: state.extra,
        ),
      ),

      GoRoute(
        path: '/profile/edit',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const ProfileEditScreen(),
          extra: state.extra,
        ),
      ),
      GoRoute(
        path: '/error-logs',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const ErrorLogsScreen(),
          extra: state.extra,
        ),
      ),

      // ── Legal ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/terms',
        pageBuilder: (_, state) {
          final viewOnly = state.uri.queryParameters['mode'] == 'view';
          return _page(
            key: state.pageKey,
            child: TermsScreen(viewOnly: viewOnly),
            extra: state.extra,
          );
        },
      ),
      GoRoute(
        path: '/privacy',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const PrivacyScreen(),
          extra: state.extra,
        ),
      ),

      // ── Report ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/report',
        pageBuilder: (_, state) => _page(
          key: state.pageKey,
          child: const ReportIssueScreen(),
          extra: state.extra,
        ),
      ),
    ],
  );
});
