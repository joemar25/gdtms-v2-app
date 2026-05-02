// DOCS: docs/development-standards.md
// DOCS: docs/features/dashboard.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/core/settings/dashboard_feel_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/features/dashboard/widgets/dashboard_components.dart';
import 'package:go_router/go_router.dart';

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

    try {
      final dao = LocalDeliveryDao.instance;
      final pending = await dao.countByStatus('FOR_DELIVERY');
      final delivered = await dao.countVisibleDelivered();
      final failedDelivery = await dao.countVisibleFailedDelivery();
      final osa = await dao.countVisibleOsa();

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
    } catch (e, stack) {
      debugPrint('[DASH] Error loading initial data: $e\n$stack');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(deliveryRefreshProvider, (prev, next) {
      _loadInitial();
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNewFeel = ref.watch(dashboardFeelProvider);

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
              context.go('/wallet', extra: {'_swipe': 'left'});
            } else {
              context.go('/profile', extra: {'_swipe': 'right'});
            }
          }
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: isDark
              ? DSColors.scaffoldDark
              : DSColors.scaffoldLight,
          appBar: const DashboardHeaderBar(),
          body: _loading
              ? const Center(
                  child: SpinKitFadingCircle(
                    color: DSColors.primary,
                    size: DSIconSize.heroSm,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: isNewFeel
                      ? DashboardNewFeel(summary: _summary, isDark: isDark)
                      : DashboardDefault(summary: _summary, isDark: isDark),
                ),
        ),
      ),
    );
  }
}
