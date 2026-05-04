// DOCS: docs/development-standards.md
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/stat_widgets.dart';
import 'package:fsi_courier_app/features/sync/widgets/sync_now_button.dart';
import 'package:go_router/go_router.dart';

// ── Layouts ──────────────────────────────────────────────────────────────────

/// Standard dashboard layout with stat cards and scan buttons.
class DashboardDefault extends StatelessWidget {
  const DashboardDefault({
    super.key,
    required this.summary,
    required this.isDark,
    required this.onRefresh,
  });

  final Map<String, dynamic> summary;
  final bool isDark;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final pendingDispatches = (summary['pending_dispatches'] ?? 0) as int;
    final pendingDeliveries = (summary['pending_deliveries'] ?? 0) as int;
    final deliveredToday = (summary['delivered_today'] ?? 0) as int;
    final failedDelivery = (summary['failed_delivery'] ?? 0) as int;
    final osa = (summary['osa'] ?? 0) as int;
    final pendingSync = (summary['pending_sync'] ?? 0) as int;
    final syncedTotal = (summary['synced_total'] ?? 0) as int;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        DSSpacing.md,
        DSSpacing.md,
        DSSpacing.md,
        DSSpacing.massive,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.dispatch_label'.tr(),
                count: '$pendingDispatches',
                icon: Icons.qr_code_rounded,
                color: DSColors.error,
                minHeight: DSStyles.statCardHeight,
                onTap: () => context.push('/dispatches'),
                subdued: pendingDispatches == 0,
                details: 'dashboard.stats.dispatch_details'.tr(),
              ).dsCardEntry(delay: DSAnimations.stagger(0)),
            ),
            DSSpacing.wSm,
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.deliveries_label'.tr(),
                count: '$pendingDeliveries',
                icon: Icons.local_shipping_outlined,
                color: DSColors.primary,
                minHeight: DSStyles.statCardHeight,
                onTap: () => context.push('/deliveries'),
                subdued: pendingDeliveries == 0,
                details: 'dashboard.stats.deliveries_details'.tr(),
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
                count: '$deliveredToday',
                icon: Icons.check_circle_outline_rounded,
                color: DSColors.primary,
                minHeight: DSStyles.statCardHeight,
                onTap: () => context.push('/delivered'),
                subdued: deliveredToday == 0,
                details: 'dashboard.stats.delivered_details'.tr(),
              ).dsCardEntry(delay: DSAnimations.stagger(2)),
            ),
            DSSpacing.wSm,
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.attempted_label'.tr(),
                count: '$failedDelivery',
                icon: Icons.assignment_return_outlined,
                color: DSColors.error,
                minHeight: DSStyles.statCardHeight,
                onTap: () => context.push('/failed-deliveries'),
                subdued: failedDelivery == 0,
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
                count: '$osa',
                icon: Icons.lock_outline_rounded,
                color: isDark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
                minHeight: DSStyles.statCardHeight,
                onTap: () => context.push('/osa'),
                subdued: osa == 0,
                details: 'dashboard.stats.misrouted_details'.tr(),
              ).dsCardEntry(delay: DSAnimations.stagger(4)),
            ),
            DSSpacing.wSm,
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.sync_label'.tr(),
                count: pendingSync > 0 ? '$pendingSync' : '$syncedTotal',
                icon: Icons.sync_rounded,
                color: pendingSync > 0
                    ? DSColors.primary
                    : (isDark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary),
                minHeight: DSStyles.statCardHeight,
                onTap: () => context.push('/sync'),
                subdued: pendingSync == 0 && syncedTotal == 0,
                details: pendingSync > 0
                    ? 'dashboard.stats.sync_pending_details'.tr()
                    : (syncedTotal > 0
                          ? 'dashboard.stats.sync_all_synced_details'.tr()
                          : 'dashboard.stats.sync_no_activity_details'.tr()),
              ).dsCardEntry(delay: DSAnimations.stagger(5)),
            ),
          ],
        ),
        DSSpacing.hSm,
        Row(
          children: [
            Expanded(
              child: ScanButton(
                label: 'dashboard.scan.dispatch_label'.tr(),
                icon: Icons.qr_code_scanner_rounded,
                color: DSColors.error,
                minHeight: DSStyles.scanButtonHeight,
                onTap: () => context.push('/scan', extra: {'mode': 'dispatch'}),
                details: 'dashboard.scan.dispatch_details'.tr(),
              ).dsCtaEntry(delay: DSAnimations.stagger(6)),
            ),
            DSSpacing.wSm,
            Expanded(
              child: ScanButton(
                label: 'dashboard.scan.pod_label'.tr(),
                icon: Icons.qr_code_scanner_rounded,
                color: DSColors.primary,
                minHeight: DSStyles.scanButtonHeight,
                onTap: () => context.push('/scan', extra: {'mode': 'pod'}),
                details: 'dashboard.scan.pod_details'.tr(),
              ).dsCtaEntry(delay: DSAnimations.stagger(7)),
            ),
          ],
        ),
        DSSpacing.hSm,
      ],
    );
  }
}

/// Premium "new feel" dashboard layout.
class DashboardNewFeel extends StatelessWidget {
  const DashboardNewFeel({
    super.key,
    required this.summary,
    required this.isDark,
    required this.onRefresh,
  });

  final Map<String, dynamic> summary;
  final bool isDark;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: DSSpacing.md),
      children: [
        DSSpacing.hSm,
        DashboardOverview(summary: summary, isDark: isDark),
        DSSpacing.hSm,
        DashboardSyncSection(
          summary: summary,
          isDark: isDark,
          onRefresh: onRefresh,
        ),
        DSSpacing.hSm,
        DashboardQuickActions(isDark: isDark),
        DSSpacing.hMassive,
      ],
    );
  }
}

// ── Components ────────────────────────────────────────────────────────────────

/// Statistics overview section.
class DashboardOverview extends StatelessWidget {
  const DashboardOverview({
    super.key,
    required this.summary,
    required this.isDark,
  });

  final Map<String, dynamic> summary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.stats.overview_title'.tr().toUpperCase(),
          style: DSTypography.caption(
            color: isDark
                ? DSColors.labelSecondaryDark
                : DSColors.labelSecondary,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ).dsFadeEntry(delay: DSAnimations.stagger(0)),
        DSSpacing.hSm,
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.dispatch_label'.tr(),
                count: '${summary['pending_dispatches'] ?? 0}',
                icon: Icons.local_shipping_rounded,
                color: DSColors.accent,
                minHeight: DSStyles.statCardHeight,
                onTap: () => context.push('/dispatches'),
              ).dsCardEntry(delay: DSAnimations.stagger(1)),
            ),
            DSSpacing.wSm,
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.deliveries_label'.tr(),
                count: '${summary['pending_deliveries'] ?? 0}',
                icon: Icons.local_shipping_outlined,
                color: DSColors.pending,
                minHeight: DSStyles.statCardHeight,
                onTap: () => context.push('/deliveries'),
              ).dsCardEntry(delay: DSAnimations.stagger(2)),
            ),
          ],
        ),
        DSSpacing.hSm,
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.delivered_label'.tr(),
                count: '${summary['delivered_today'] ?? 0}',
                icon: Icons.check_circle_rounded,
                color: DSColors.success,
                minHeight: DSStyles.statCardHeight,
                onTap: () => context.push('/delivered'),
              ).dsCardEntry(delay: DSAnimations.stagger(3)),
            ),
            DSSpacing.wSm,
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.attempted_label'.tr(),
                count: '${summary['failed_delivery'] ?? 0}',
                icon: Icons.warning_rounded,
                color: DSColors.error,
                minHeight: DSStyles.statCardHeight,
                onTap: () => context.push('/failed-deliveries'),
              ).dsCardEntry(delay: DSAnimations.stagger(4)),
            ),
          ],
        ),
        DSSpacing.hSm,
        StatCard(
          label: 'dashboard.stats.misrouted_label'.tr(),
          count: '${summary['osa'] ?? 0}',
          icon: Icons.location_on_rounded,
          color: DSColors.warning,
          minHeight: DSStyles.statCardHeight,
          onTap: () => context.push('/osa'),
        ).dsCardEntry(delay: DSAnimations.stagger(5)),
      ],
    );
  }
}

/// Sync and connectivity status section.
class DashboardSyncSection extends ConsumerWidget {
  const DashboardSyncSection({
    super.key,
    required this.summary,
    required this.isDark,
    required this.onRefresh,
  });

  final Map<String, dynamic> summary;
  final bool isDark;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingSync = summary['pending_sync'] ?? 0;
    final connStatus = ref.watch(connectionStatusProvider);
    final isOnline = connStatus == ConnectionStatus.online;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.stats.sync_connectivity_title'.tr().toUpperCase(),
          style: DSTypography.caption(
            color: isDark
                ? DSColors.labelSecondaryDark
                : DSColors.labelSecondary,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ).dsFadeEntry(delay: DSAnimations.stagger(6)),
        DSSpacing.hMd,
        // Plain Container — no wrapping GestureDetector — so every child
        // widget owns its own gesture recognizer with zero arena competition.
        Container(
          padding: const EdgeInsets.all(DSSpacing.sm),
          decoration: BoxDecoration(
            color: DSColors.primary,
            borderRadius: BorderRadius.circular(DSStyles.radiusMD),
          ),
          child: Row(
            children: [
              // Sync icon badge
              Container(
                padding: const EdgeInsets.all(DSSpacing.sm),
                decoration: BoxDecoration(
                  color: DSColors.white,
                  borderRadius: BorderRadius.circular(DSStyles.radiusFull),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: DSColors.primary,
                  size: DSIconSize.md,
                ),
              ),
              DSSpacing.wSm,
              // Status text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pendingSync == 0
                          ? 'dashboard.stats.synced_all'.tr()
                          : 'dashboard.stats.pending_sync'.tr(
                              namedArgs: {'count': '$pendingSync'},
                            ),
                      style: DSTypography.body(
                        color: DSColors.white,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Container(
                          width: DSSpacing.sm,
                          height: DSSpacing.sm,
                          decoration: BoxDecoration(
                            color: switch (connStatus) {
                              ConnectionStatus.online => DSColors.white,
                              ConnectionStatus.apiUnreachable =>
                                DSColors.warning,
                              ConnectionStatus.networkOffline => DSColors.error,
                            },
                            borderRadius: BorderRadius.circular(
                              DSStyles.radiusFull,
                            ),
                          ),
                        ),
                        DSSpacing.wXs,
                        Text(switch (connStatus) {
                          ConnectionStatus.online =>
                            'dashboard.stats.online'.tr(),
                          ConnectionStatus.apiUnreachable =>
                            'dashboard.stats.api_unavailable'.tr(),
                          ConnectionStatus.networkOffline =>
                            'dashboard.stats.offline'.tr(),
                        }, style: DSTypography.caption(color: DSColors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              // SYNC NOW button — owns its tap; no competing parent.
              if (isOnline)
                Consumer(
                  builder: (ctx, r, _) {
                    final isSyncing = r.watch(syncManagerProvider).isSyncing;
                    return TextButton.icon(
                      onPressed: isSyncing
                          ? null
                          : () => showSyncOverlay(ctx, r),
                      style: TextButton.styleFrom(
                        backgroundColor: DSColors.white,
                        foregroundColor: DSColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: DSSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DSStyles.radiusMD,
                          ),
                        ),
                      ),
                      icon: isSyncing
                          ? const Icon(Icons.sync_rounded, size: DSIconSize.xs)
                                .animate(onPlay: (c) => c.repeat())
                                .rotate(
                                  duration: const Duration(milliseconds: 1000),
                                )
                          : const Icon(Icons.sync_rounded, size: DSIconSize.xs),
                      label: Text(
                        isSyncing
                            ? 'sync.actions.syncing'.tr().toUpperCase()
                            : 'sync.actions.sync_now'.tr().toUpperCase(),
                        style: DSTypography.button(
                          color: isSyncing
                              ? DSColors.primary.withValues(alpha: 0.5)
                              : DSColors.primary,
                          fontSize: DSTypography.sizeSm,
                        ),
                      ),
                    );
                  },
                ),
              // Chevron navigates to sync history — separate tap target.
              IconButton(
                onPressed: () => context.push('/sync'),
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: DSColors.white,
                  size: DSIconSize.md,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ).dsCardEntry(delay: DSAnimations.stagger(7)),
      ],
    );
  }
}

/// Quick actions section.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'dashboard.actions.quick_title'.tr().toUpperCase(),
          style: DSTypography.caption(
            color: isDark
                ? DSColors.labelSecondaryDark
                : DSColors.labelSecondary,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ).dsFadeEntry(delay: DSAnimations.stagger(8)),
        DSSpacing.hSm,
        Row(
          children: [
            Expanded(
              child: ScanButton(
                label: 'dashboard.actions.dispatch_action'.tr(),
                details: 'dashboard.actions.dispatch_subtitle'.tr(),
                icon: Icons.qr_code_scanner_rounded,
                color: DSColors.accent,
                minHeight: DSStyles.scanButtonHeight,
                onTap: () => context.push('/scan', extra: {'mode': 'dispatch'}),
              ).dsCtaEntry(delay: DSAnimations.stagger(9)),
            ),
            DSSpacing.wSm,
            Expanded(
              child: ScanButton(
                label: 'dashboard.actions.pod_action'.tr(),
                details: 'dashboard.actions.pod_subtitle'.tr(),
                icon: Icons.camera_alt_rounded,
                color: DSColors.primary,
                minHeight: DSStyles.scanButtonHeight,
                onTap: () => context.push('/scan', extra: {'mode': 'pod'}),
              ).dsCtaEntry(delay: DSAnimations.stagger(10)),
            ),
          ],
        ),
      ],
    );
  }
}
