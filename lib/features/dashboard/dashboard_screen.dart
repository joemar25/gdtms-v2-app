// DOCS: docs/features/dashboard.md — update that file when you edit this one.

// =============================================================================
// dashboard_screen.dart
// =============================================================================
//
// Purpose:
//   The main home screen shown immediately after login. It gives the courier a
//   real-time summary of their delivery workload for the current day and quick
//   navigation to every major feature of the app.
//
// Contents:
//   • Summary stat cards — Pending, Delivered, Failed, OSA counts (tappable,
//     each navigates to the corresponding filtered DeliveryStatusListScreen).
//   • Shortcut cards — Scan, Dispatch, History (Sync), Wallet.
//   • Offline banner & connectivity indicator.
//   • Floating bottom navigation bar (Dashboard | Scan | Profile).
//   • Pull-to-refresh triggers a full delivery bootstrap from the server.
//
// Data:
//   Counts are read from local SQLite via [LocalDeliveryDao] — no live API call
//   on render. A bootstrap/sync is triggered automatically when the app comes
//   online or the user pulls to refresh.
//
// Navigation:
//   Route: /dashboard (root after auth)
//   Hosts: FloatingBottomNavBar — shared with ScanScreen and ProfileScreen
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/shared/widgets/stat_widgets.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _loading = true;
  Map<String, dynamic> _summary = {};
  double _horizontalDrag = 0.0;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Pull-to-refresh handler.
  /// When online: runs a full server sync first so counts reflect fresh data.
  /// When offline: skips sync and just reloads from SQLite.
  Future<void> _onRefresh() async {
    final isOnline = ref.read(isOnlineProvider);
    if (isOnline) {
      await DeliveryBootstrapService.instance.syncFromApi(
        ref.read(apiClientProvider),
      );
    }
    await _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // Always derive delivery counts from SQLite — same source as list screens.
    // This guarantees dashboard numbers always match what clicking a card shows.
    final dao = LocalDeliveryDao.instance;
    final pending = await dao.countByStatus('PENDING');
    final delivered = await dao.countVisibleDelivered();
    final failedDelivery = await dao.countVisibleFailedDelivery();
    final osa = await dao.countVisibleOsa();
    debugPrint(
      '[DASH] _loadInitial: pending=$pending delivered=$delivered failed=$failedDelivery osa=$osa',
    );

    // pending_dispatches cannot be derived from SQLite — try API when online.
    int pendingDispatches = 0;
    final isOnline = ref.read(isOnlineProvider);
    if (isOnline) {
      final api = ref.read(apiClientProvider);
      final summaryResult = await api.get<Map<String, dynamic>>(
        '/dashboard-summary',
        queryParameters: {'paid': 'all'},
        parser: parseApiMap,
      );
      if (summaryResult case ApiSuccess<Map<String, dynamic>>(:final data)) {
        final d = mapFromKey(data, 'data');
        pendingDispatches = (d['pending_dispatches'] as num?)?.toInt() ?? 0;
      }
    }

    // fetch sync counts — scoped to the current courier only
    final courierId =
        await ref.read(authStorageProvider).getLastCourierId() ?? '';
    final pendingSync = await SyncOperationsDao.instance.getPendingCount(
      courierId,
    );
    final syncedTotal = await SyncOperationsDao.instance.getSyncedCount(
      courierId,
    );

    if (!mounted) return;

    _summary = {
      'pending_dispatches': pendingDispatches,
      'pending_deliveries': pending,
      'delivered_today': delivered,
      'failed_delivery': failedDelivery,
      'osa': osa,
      'pending_sync': pendingSync,
      'synced_total': syncedTotal,
    };

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(deliveryRefreshProvider, (prev, next) {
      debugPrint('[DASH] deliveryRefreshProvider changed $prev → $next');
      _loadInitial();
    });
    final auth = ref.watch(authProvider);
    final firstName = auth.courier?['first_name']?.toString() ?? 'Courier';
    // final courierCode = auth.courier?['courier_code']?.toString() ?? '-';
    final greeting = _getGreeting();

    final pendingDispatchCount = _summary['pending_dispatches'] ?? 0;
    final deliveriesCount = _summary['pending_deliveries'] ?? 0;
    final failedDeliveryCount = _summary['failed_delivery'] ?? 0;
    final osaCount = _summary['osa'] ?? 0;
    final deliveredCount = _summary['delivered_today'] ?? 0;

    // Use summary values for sync to ensure consistency after load
    final pendingSyncCount = _summary['pending_sync'] ?? 0;
    final syncedTotalCount = _summary['synced_total'] ?? 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await ConfirmationDialog.show(
          context,
          title: 'Exit App',
          subtitle: 'Are you sure you want to exit?',
          confirmLabel: 'Exit',
          cancelLabel: 'Stay',
          isDestructive: true,
        );
        if (shouldExit == true && mounted) SystemNavigator.pop();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) =>
            _horizontalDrag += details.delta.dx,
        onHorizontalDragEnd: (details) {
          final dx = _horizontalDrag;
          _horizontalDrag = 0.0;
          final velocity = details.primaryVelocity ?? 0.0;
          if (dx.abs() > 60 || velocity.abs() > 300) {
            if (dx < 0 || velocity < 0) {
              // swipe left → Wallet
              context.go('/wallet', extra: {'_swipe': 'left'});
            } else {
              // swipe right → Profile (wrap-around)
              context.go('/profile', extra: {'_swipe': 'right'});
            }
          }
        },
        child: Scaffold(
          extendBody: true,
          appBar: const AppHeaderBar(
            title: 'Dashboard',
            pageIcon: Icons.dashboard_rounded,
          ),
          // bottomNavigationBar: const FloatingBottomNavBar(
          //   currentPath: '/dashboard',
          // ),
          body: _loading
              ? Center(
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: Lottie.asset(AppAssets.animHourGlass),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      // ── Greeting ─────────────────────────────────────────────
                      Text(
                            '$greeting, $firstName!',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: -0.1, end: 0),
                      const SizedBox(height: 20),

                      // ── 4 Summary Boxes ───────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child:
                                StatCard(
                                      label: 'DISPATCH',
                                      count: '$pendingDispatchCount',
                                      icon: Icons.qr_code_rounded,
                                      color: ColorStyles.grabOrange,
                                      onTap: pendingDispatchCount == 0
                                          ? null
                                          : () => context.push('/dispatches'),
                                      details: 'Waiting for acceptance.',
                                    )
                                    .animate()
                                    .fadeIn(delay: 200.ms)
                                    .slideY(begin: 0.1, end: 0),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                StatCard(
                                      label: 'DELIVERIES',
                                      count: '$deliveriesCount',
                                      icon: Icons.local_shipping_outlined,
                                      color: ColorStyles.grabGreen,
                                      onTap: deliveriesCount == 0
                                          ? null
                                          : () => context.push('/deliveries'),
                                      details: "Today's for deliveries.",
                                    )
                                    .animate()
                                    .fadeIn(delay: 300.ms)
                                    .slideY(begin: 0.1, end: 0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child:
                                StatCard(
                                      label: 'DELIVERED',
                                      count: '$deliveredCount',
                                      icon: Icons.check_circle_outline_rounded,
                                      color: ColorStyles.grabGreen,
                                      onTap: deliveredCount == 0
                                          ? null
                                          : () => context.push('/delivered'),
                                      details: "Today's delivered.",
                                    )
                                    .animate()
                                    .fadeIn(delay: 400.ms)
                                    .slideY(begin: 0.1, end: 0),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                StatCard(
                                      label: 'Attempted',
                                      count: '$failedDeliveryCount',
                                      icon: Icons.assignment_return_outlined,
                                      color: Colors.red,
                                      onTap: failedDeliveryCount == 0
                                          ? null
                                          : () => context.push(
                                              '/failed-deliveries',
                                            ),
                                      subdued: true,
                                      details:
                                          "Today's attempted or failed deliveries.",
                                    )
                                    .animate()
                                    .fadeIn(delay: 500.ms)
                                    .slideY(begin: 0.1, end: 0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child:
                                StatCard(
                                      label: 'Misrouted',
                                      count: '$osaCount',
                                      icon: Icons.lock_outline_rounded,
                                      color: Colors.grey,
                                      onTap: osaCount == 0
                                          ? null
                                          : () => context.push('/osa'),
                                      subdued: true,
                                      details: "Today's misrouted deliveries.",
                                    )
                                    .animate()
                                    .fadeIn(delay: 600.ms)
                                    .slideY(begin: 0.1, end: 0),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child:
                                StatCard(
                                      label: 'SYNC',
                                      count: pendingSyncCount > 0
                                          ? '$pendingSyncCount'
                                          : '$syncedTotalCount',
                                      icon: Icons.sync_rounded,
                                      color: pendingSyncCount > 0
                                          ? Colors.blueAccent
                                          : Colors.blueGrey,
                                      onTap: () => context.push('/sync'),
                                      subdued:
                                          pendingSyncCount == 0 &&
                                          syncedTotalCount == 0,
                                      details: pendingSyncCount > 0
                                          ? 'Pending updates.'
                                          : (syncedTotalCount > 0
                                                ? 'All synced.'
                                                : 'No activity.'),
                                    )
                                    .animate()
                                    .fadeIn(delay: 700.ms)
                                    .slideY(begin: 0.1, end: 0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Scan Action Buttons ────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child:
                                ScanButton(
                                      label: 'SCAN DISPATCH',
                                      icon: Icons.qr_code_scanner_rounded,
                                      color: ColorStyles.grabOrange,
                                      onTap: () => context.push(
                                        '/scan',
                                        extra: {'mode': 'dispatch'},
                                      ),
                                      details:
                                          'Scan a dispatch barcode\nto check eligibility.',
                                    )
                                    .animate()
                                    .fadeIn(delay: 800.ms)
                                    .scale(
                                      begin: const Offset(0.95, 0.95),
                                      end: const Offset(1, 1),
                                    ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child:
                                ScanButton(
                                      label: 'SCAN POD',
                                      icon: Icons.qr_code_scanner_rounded,
                                      color: ColorStyles.grabGreen,
                                      onTap: () => context.push(
                                        '/scan',
                                        extra: {'mode': 'pod'},
                                      ),
                                      details:
                                          'Scan a delivery barcode to\nfind and update POD.',
                                    )
                                    .animate()
                                    .fadeIn(delay: 900.ms)
                                    .scale(
                                      begin: const Offset(0.95, 0.95),
                                      end: const Offset(1, 1),
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
