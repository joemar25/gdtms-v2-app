// DOCS: docs/development-standards.md
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

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
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
import 'package:fsi_courier_app/design_system/design_system.dart';

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
    final pending = await dao.countByStatus('FOR_DELIVERY');
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

    final pendingDispatchCount = _summary['pending_dispatches'] ?? 0;
    final deliveriesCount = _summary['pending_deliveries'] ?? 0;
    final failedDeliveryCount = _summary['failed_delivery'] ?? 0;
    final osaCount = _summary['osa'] ?? 0;
    final deliveredCount = _summary['delivered_today'] ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use summary values for sync to ensure consistency after load
    final pendingSyncCount = _summary['pending_sync'] ?? 0;
    final syncedTotalCount = _summary['synced_total'] ?? 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await ConfirmationDialog.show(
          context,
          title: 'dashboard.exit_confirm_title'.tr(),
          subtitle: 'dashboard.exit_confirm_subtitle'.tr(),
          confirmLabel: 'dashboard.exit_confirm_confirm'.tr(),
          cancelLabel: 'dashboard.exit_confirm_cancel'.tr(),
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
          appBar: const DashboardHeaderBar(),
          // bottomNavigationBar: const FloatingBottomNavBar(
          //   currentPath: '/dashboard',
          // ),
          body: _loading
              ? const Center(
                  child: SpinKitFadingCircle(
                    color: DSColors.primary,
                    size: DSIconSize.heroSm,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      DSSpacing.md,
                      DSSpacing.md,
                      DSSpacing.md,
                      DSSpacing.massive,
                    ),
                    children: [
                      // ── 4 Summary Boxes ───────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'dashboard.stats.dispatch_label'.tr(),
                              count: '$pendingDispatchCount',
                              icon: Icons.qr_code_rounded,
                              color: DSColors.error,
                              onTap: pendingDispatchCount == 0
                                  ? null
                                  : () => context.push('/dispatches'),
                              details: 'dashboard.stats.dispatch_details'.tr(),
                            ).dsCardEntry(delay: DSAnimations.stagger(0)),
                          ),
                          DSSpacing.wSm,
                          Expanded(
                            child: StatCard(
                              label: 'dashboard.stats.deliveries_label'.tr(),
                              count: '$deliveriesCount',
                              icon: Icons.local_shipping_outlined,
                              color: DSColors.primary,
                              onTap: deliveriesCount == 0
                                  ? null
                                  : () => context.push('/deliveries'),
                              details: 'dashboard.stats.deliveries_details'
                                  .tr(),
                            ).dsCardEntry(delay: DSAnimations.stagger(1)),
                          ),
                        ],
                      ),
                      DSSpacing.hSm,
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'dashboard.stats.delivered_label'.tr(),
                              count: '$deliveredCount',
                              icon: Icons.check_circle_outline_rounded,
                              color: DSColors.primary,
                              onTap: deliveredCount == 0
                                  ? null
                                  : () => context.push('/delivered'),
                              details: 'dashboard.stats.delivered_details'.tr(),
                            ).dsCardEntry(delay: DSAnimations.stagger(2)),
                          ),
                          DSSpacing.wSm,
                          Expanded(
                            child: StatCard(
                              label: 'dashboard.stats.attempted_label'.tr(),
                              count: '$failedDeliveryCount',
                              icon: Icons.assignment_return_outlined,
                              color: DSColors.error,
                              onTap: failedDeliveryCount == 0
                                  ? null
                                  : () => context.push('/failed-deliveries'),
                              subdued: true,
                              details: 'dashboard.stats.attempted_details'.tr(),
                            ).dsCardEntry(delay: DSAnimations.stagger(3)),
                          ),
                        ],
                      ),
                      DSSpacing.hSm,
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'dashboard.stats.misrouted_label'.tr(),
                              count: '$osaCount',
                              icon: Icons.lock_outline_rounded,
                              color: isDark
                                  ? DSColors.labelSecondaryDark
                                  : DSColors.labelSecondary,
                              onTap: osaCount == 0
                                  ? null
                                  : () => context.push('/osa'),
                              subdued: true,
                              details: 'dashboard.stats.misrouted_details'.tr(),
                            ).dsCardEntry(delay: DSAnimations.stagger(4)),
                          ),
                          DSSpacing.wSm,
                          Expanded(
                            child: StatCard(
                              label: 'dashboard.stats.sync_label'.tr(),
                              count: pendingSyncCount > 0
                                  ? '$pendingSyncCount'
                                  : '$syncedTotalCount',
                              icon: Icons.sync_rounded,
                              color: pendingSyncCount > 0
                                  ? DSColors.primary
                                  : (isDark
                                        ? DSColors.labelSecondaryDark
                                        : DSColors.labelSecondary),
                              onTap: () => context.push('/sync'),
                              subdued:
                                  pendingSyncCount == 0 &&
                                  syncedTotalCount == 0,
                              details: pendingSyncCount > 0
                                  ? 'dashboard.stats.sync_pending_details'.tr()
                                  : (syncedTotalCount > 0
                                        ? 'dashboard.stats.sync_all_synced_details'
                                              .tr()
                                        : 'dashboard.stats.sync_no_activity_details'
                                              .tr()),
                            ).dsCardEntry(delay: DSAnimations.stagger(5)),
                          ),
                        ],
                      ),
                      DSSpacing.hLg,

                      // ── Scan Action Buttons ────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: ScanButton(
                              label: 'dashboard.scan.dispatch_label'.tr(),
                              icon: Icons.qr_code_scanner_rounded,
                              color: DSColors.error,
                              onTap: () => context.push(
                                '/scan',
                                extra: {'mode': 'dispatch'},
                              ),
                              details: 'dashboard.scan.dispatch_details'.tr(),
                            ).dsCtaEntry(delay: DSAnimations.stagger(6)),
                          ),
                          DSSpacing.wSm,
                          Expanded(
                            child: ScanButton(
                              label: 'dashboard.scan.pod_label'.tr(),
                              icon: Icons.qr_code_scanner_rounded,
                              color: DSColors.primary,
                              onTap: () =>
                                  context.push('/scan', extra: {'mode': 'pod'}),
                              details: 'dashboard.scan.pod_details'.tr(),
                            ).dsCtaEntry(delay: DSAnimations.stagger(7)),
                          ),
                        ],
                      ),
                      DSSpacing.hLg,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
