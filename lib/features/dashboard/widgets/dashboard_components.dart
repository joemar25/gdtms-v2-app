// DOCS: docs/development-standards.md
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/stat_widgets.dart';
import 'package:go_router/go_router.dart';

// ── Layouts ──────────────────────────────────────────────────────────────────

/// Standard dashboard layout with stat cards and scan buttons.
class DashboardDefault extends StatelessWidget {
  const DashboardDefault({
    super.key,
    required this.summary,
    required this.isDark,
  });

  final Map<String, dynamic> summary;
  final bool isDark;

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
        DSSpacing.hLg,
        Row(
          children: [
            Expanded(
              child: ScanButton(
                label: 'dashboard.scan.dispatch_label'.tr(),
                icon: Icons.qr_code_scanner_rounded,
                color: DSColors.error,
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
                onTap: () => context.push('/scan', extra: {'mode': 'pod'}),
                details: 'dashboard.scan.pod_details'.tr(),
              ).dsCtaEntry(delay: DSAnimations.stagger(7)),
            ),
          ],
        ),
        DSSpacing.hLg,
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
  });

  final Map<String, dynamic> summary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: DSSpacing.md),
      children: [
        DSSpacing.hMd,
        DashboardOverview(summary: summary, isDark: isDark),
        DSSpacing.hLg,
        DashboardSyncSection(summary: summary, isDark: isDark),
        DSSpacing.hLg,
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
    return Container(
      padding: const EdgeInsets.all(DSSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? DSColors.secondarySurfaceDark : DSColors.successSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? DSColors.success : DSColors.successText,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'dashboard.stats.overview_title'.tr().toUpperCase(),
            style: DSTypography.caption(
              color: isDark
                  ? DSColors.labelSecondaryDark
                  : DSColors.labelSecondary,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
          DSSpacing.hMd,
          Row(
            children: [
              Expanded(
                child: DashboardStatCard(
                  label: 'dashboard.stats.dispatch_label'.tr(),
                  count: summary['pending_dispatches'] ?? 0,
                  icon: Icons.local_shipping_rounded,
                  color: DSColors.accent,
                  isDark: isDark,
                  onTap: () => context.push('/dispatches'),
                ),
              ),
              DSSpacing.wMd,
              Expanded(
                child: DashboardStatCard(
                  label: 'dashboard.stats.deliveries_label'.tr(),
                  count: summary['pending_deliveries'] ?? 0,
                  icon: Icons.local_shipping_outlined,
                  color: DSColors.pending,
                  isDark: isDark,
                  onTap: () => context.push('/deliveries'),
                ),
              ),
            ],
          ),
          DSSpacing.hMd,
          Row(
            children: [
              Expanded(
                child: DashboardStatCard(
                  label: 'dashboard.stats.delivered_label'.tr(),
                  count: summary['delivered_today'] ?? 0,
                  icon: Icons.check_circle_rounded,
                  color: DSColors.success,
                  isDark: isDark,
                  onTap: () => context.push('/delivered'),
                ),
              ),
              DSSpacing.wMd,
              Expanded(
                child: DashboardStatCard(
                  label: 'dashboard.stats.attempted_label'.tr(),
                  count: summary['failed_delivery'] ?? 0,
                  icon: Icons.warning_rounded,
                  color: DSColors.error,
                  isDark: isDark,
                  onTap: () => context.push('/failed-deliveries'),
                ),
              ),
            ],
          ),
          DSSpacing.hMd,
          DashboardWideStatCard(
            label: 'dashboard.stats.misrouted_label'.tr(),
            count: summary['osa'] ?? 0,
            icon: Icons.location_on_rounded,
            color: DSColors.warning,
            isDark: isDark,
            onTap: () => context.push('/osa'),
          ),
        ],
      ),
    );
  }
}

/// A compact stat card for the new-feel layout.
class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label
        .split(' ')
        .map(
          (s) => s.isEmpty
              ? ''
              : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}',
        )
        .join(' ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DSSpacing.sm),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.1)
              : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DSSpacing.xs),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            DSSpacing.wSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayLabel,
                    style: DSTypography.caption(
                      color: color,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 10),
                  ),
                  Text(
                    '$count',
                    style: DSTypography.heading(
                      color: color,
                    ).copyWith(fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A wide stat card for secondary statistics.
class DashboardWideStatCard extends StatelessWidget {
  const DashboardWideStatCard({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label
        .split(' ')
        .map(
          (s) => s.isEmpty
              ? ''
              : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}',
        )
        .join(' ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DSSpacing.sm),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.05)
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            DSSpacing.wSm,
            Text(
              displayLabel,
              style: DSTypography.caption(
                color: color,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '$count',
              style: DSTypography.body(
                color: color,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sync and connectivity status section.
class DashboardSyncSection extends ConsumerWidget {
  const DashboardSyncSection({
    super.key,
    required this.summary,
    required this.isDark,
  });

  final Map<String, dynamic> summary;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingSync = summary['pending_sync'] ?? 0;
    final isOnline = ref.watch(isOnlineProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${'dashboard.stats.sync_label'.tr().toUpperCase()} & CONNECTIVITY',
          style: DSTypography.caption(
            color: isDark
                ? DSColors.labelSecondaryDark
                : DSColors.labelSecondary,
          ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
        DSSpacing.hMd,
        Container(
          padding: const EdgeInsets.all(DSSpacing.sm),
          decoration: BoxDecoration(
            color: DSColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DSSpacing.sm),
                decoration: BoxDecoration(
                  color: DSColors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: DSColors.primary,
                  size: 20,
                ),
              ),
              DSSpacing.wSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOnline ? DSColors.white : DSColors.error,
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        DSSpacing.wXs,
                        Text(
                          isOnline
                              ? 'dashboard.stats.online'.tr()
                              : 'dashboard.stats.offline'.tr(),
                          style: DSTypography.caption(color: DSColors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push('/sync'),
                style: TextButton.styleFrom(
                  backgroundColor: DSColors.white,
                  foregroundColor: DSColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: DSSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('dashboard.actions.sync'.tr().toUpperCase()),
              ),
            ],
          ),
        ),
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
        ),
        DSSpacing.hMd,
        Row(
          children: [
            Expanded(
              child: DashboardActionCard(
                label: 'dashboard.actions.pod_action'.tr(),
                sublabel: 'dashboard.actions.pod_subtitle'.tr(),
                icon: Icons.camera_alt_rounded,
                color: DSColors.primary,
                isDark: isDark,
                onTap: () => context.push('/scan', extra: {'mode': 'pod'}),
              ),
            ),
            DSSpacing.wMd,
            Expanded(
              child: DashboardActionCard(
                label: 'dashboard.actions.dispatch_action'.tr(),
                sublabel: 'dashboard.actions.dispatch_subtitle'.tr(),
                icon: Icons.qr_code_scanner_rounded,
                color: DSColors.accent,
                isDark: isDark,
                onTap: () => context.push('/scan', extra: {'mode': 'dispatch'}),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A card for quick actions on the dashboard.
class DashboardActionCard extends StatelessWidget {
  const DashboardActionCard({
    super.key,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(DSSpacing.md),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(DSSpacing.sm),
              decoration: BoxDecoration(
                color: DSColors.white,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(
              label,
              style: DSTypography.body(
                color: DSColors.white,
              ).copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              sublabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DSTypography.caption(
                color: DSColors.white,
              ).copyWith(fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
