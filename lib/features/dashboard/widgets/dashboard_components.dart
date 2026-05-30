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
class DashboardDefault extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingDispatches = (summary['pending_dispatches'] ?? 0) as int;
    final pendingDeliveries = (summary['pending_deliveries'] ?? 0) as int;
    final deliveredToday = (summary['delivered_today'] ?? 0) as int;
    final failedDelivery = (summary['failed_delivery'] ?? 0) as int;
    final misrouted = (summary['misrouted'] ?? 0) as int;
    final pendingSync = ref.watch(pendingSyncCountProvider);
    final syncedTotal = ref.watch(syncedSyncCountProvider);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        DSSpacing.md,
        DSSpacing.md,
        DSSpacing.md,
        DSSpacing.massive,
      ),
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
              child: StatCard(
                label: 'dashboard.stats.dispatch_label'.tr(),
                count: '$pendingDispatches',
                icon: Icons.qr_code_rounded,
                color: DSColors.error,
                minHeight: 140,
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
                minHeight: 140,
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
                minHeight: 140,
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
                minHeight: 140,
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
                count: '$misrouted',
                icon: Icons.location_on_rounded,
                color: DSColors.warning,
                label: 'dashboard.stats.misrouted_label'.tr(),
                minHeight: 140,
                onTap: () => context.push('/misrouted'),
                subdued: misrouted == 0,
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
                minHeight: 140,
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
              child: ScanButton(
                label: 'dashboard.scan.dispatch_label'.tr(),
                icon: Icons.qr_code_scanner_rounded,
                color: DSColors.error,
                minHeight: 140,
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
                minHeight: 140,
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
        DSSpacing.hMd,
        DashboardOverview(summary: summary, isDark: isDark),
        DSSpacing.hLg,
        DashboardSyncSection(
          summary: summary,
          isDark: isDark,
          onRefresh: onRefresh,
        ),
        DSSpacing.hLg,
        DashboardQuickActions(isDark: isDark),
        DSSpacing.hMassive,
      ],
    );
  }
}

// ── Components ────────────────────────────────────────────────────────────────

/// Statistics overview section.
class DashboardOverview extends ConsumerWidget {
  const DashboardOverview({
    super.key,
    required this.summary,
    required this.isDark,
  });

  final Map<String, dynamic> summary;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = (summary['pending_deliveries'] ?? 0) as int;
    final delivered = (summary['delivered_today'] ?? 0) as int;
    final failed = (summary['failed_delivery'] ?? 0) as int;
    final misrouted = (summary['misrouted'] ?? 0) as int;

    final completed = delivered + failed + misrouted;
    final total = pending + completed;
    final progress = total > 0 ? completed / total : 0.0;
    final progressPercent = (progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Courier Progress Header Card
        DSHeroCard(
          padding: const EdgeInsets.all(DSSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'dashboard.stats.overview_title'.tr().toUpperCase(),
                          style: DSTypography.caption(
                            color: DSColors.white.withValues(alpha: 0.65),
                          ).copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            fontSize: 9.0,
                          ),
                        ),
                        DSSpacing.hXs,
                        Text(
                          DateFormat('EEEE, MMMM d', context.locale.toString()).format(DateTime.now()),
                          style: DSTypography.heading(color: DSColors.white).copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DSSpacing.sm,
                      vertical: DSSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: DSColors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(DSStyles.radiusPill),
                      border: Border.all(
                        color: DSColors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      '$progressPercent%',
                      style: DSTypography.labelCaps(color: DSColors.white).copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              DSSpacing.hMd,
              // Progress bar
              Stack(
                children: [
                  Container(
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: DSColors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 8.0,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [DSColors.white, DSColors.success],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(4.0),
                        boxShadow: [
                          BoxShadow(
                            color: DSColors.success.withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              DSSpacing.hSm,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${'dashboard.stats.deliveries_label'.tr()}: $pending',
                    style: DSTypography.caption(
                      color: DSColors.white.withValues(alpha: 0.75),
                    ).copyWith(fontSize: 11.0, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${'dashboard.stats.delivered_label'.tr()}: $completed / $total',
                    style: DSTypography.caption(
                      color: DSColors.white.withValues(alpha: 0.75),
                    ).copyWith(fontSize: 11.0, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ).dsHeroEntry(),
        DSSpacing.hLg,
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
              child: StatCard(
                label: 'dashboard.stats.dispatch_label'.tr(),
                count: '${summary['pending_dispatches'] ?? 0}',
                icon: Icons.local_shipping_rounded,
                color: DSColors.accent,
                onTap: () => context.push('/dispatches'),
              ),
            ),
            DSSpacing.wMd,
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.deliveries_label'.tr(),
                count: '${summary['pending_deliveries'] ?? 0}',
                icon: Icons.local_shipping_outlined,
                color: DSColors.pending,
                onTap: () => context.push('/deliveries'),
              ),
            ),
          ],
        ),
        DSSpacing.hMd,
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.delivered_label'.tr(),
                count: '${summary['delivered_today'] ?? 0}',
                icon: Icons.check_circle_rounded,
                color: DSColors.success,
                onTap: () => context.push('/delivered'),
              ),
            ),
            DSSpacing.wMd,
            Expanded(
              child: StatCard(
                label: 'dashboard.stats.attempted_label'.tr(),
                count: '${summary['failed_delivery'] ?? 0}',
                icon: Icons.warning_rounded,
                color: DSColors.error,
                onTap: () => context.push('/failed-deliveries'),
              ),
            ),
          ],
        ),
        DSSpacing.hMd,
        StatCard(
          label: 'dashboard.stats.misrouted_label'.tr(),
          count: '${summary['misrouted'] ?? 0}',
          icon: Icons.location_on_rounded,
          color: DSColors.warning,
          onTap: () => context.push('/misrouted'),
        ),
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
    final pendingSync = ref.watch(pendingSyncCountProvider);
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
        ),
        DSSpacing.hMd,
        // Plain Container — no wrapping GestureDetector — so every child
        // widget owns its own gesture recognizer with zero arena competition.
        Container(
          padding: const EdgeInsets.all(DSSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      DSColors.cardDark,
                      Color.alphaBlend(
                        DSColors.primary.withValues(alpha: 0.05),
                        DSColors.cardDark,
                      ),
                    ]
                  : [
                      DSColors.cardLight,
                      Color.alphaBlend(
                        DSColors.primary.withValues(alpha: 0.03),
                        DSColors.cardLight,
                      ),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DSStyles.radiusXL),
            border: Border.all(
              color: DSColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: DSColors.primary.withValues(alpha: isDark ? 0.12 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Sync icon badge in a glowing circular frame
              Container(
                padding: const EdgeInsets.all(DSSpacing.sm),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      DSColors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                      DSColors.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DSColors.primary.withValues(alpha: isDark ? 0.4 : 0.2),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  Icons.sync_rounded,
                  color: isDark ? const Color(0xFF4ADE80) : DSColors.primary,
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
                        color: isDark ? DSColors.white : DSColors.labelPrimary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    DSSpacing.hXs,
                    Row(
                      children: [
                        _PulsingDot(connStatus: connStatus),
                        DSSpacing.wXs,
                        Text(
                          switch (connStatus) {
                            ConnectionStatus.online =>
                              'dashboard.stats.online'.tr(),
                            ConnectionStatus.apiUnreachable =>
                              'dashboard.stats.api_unavailable'.tr(),
                            ConnectionStatus.networkOffline =>
                              'dashboard.stats.offline'.tr(),
                          },
                          style: DSTypography.caption(
                            color: isDark
                                ? DSColors.labelSecondaryDark
                                : DSColors.labelSecondary,
                          ),
                        ),
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
                    return ElevatedButton.icon(
                      onPressed: isSyncing
                          ? null
                          : () => showSyncOverlay(ctx, r),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DSColors.primary,
                        foregroundColor: DSColors.white,
                        elevation: 4,
                        shadowColor: DSColors.primary.withValues(alpha: 0.3),
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DSSpacing.md,
                          vertical: DSSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DSStyles.radiusFull),
                        ),
                      ),
                      icon: isSyncing
                          ? const Icon(Icons.sync_rounded, size: 14.0)
                                .animate(onPlay: (c) => c.repeat())
                                .rotate(
                                  duration: const Duration(milliseconds: 1000),
                                )
                          : const Icon(Icons.sync_rounded, size: 14.0),
                      label: Text(
                        isSyncing
                            ? 'sync.actions.syncing'.tr().toUpperCase()
                            : 'sync.actions.sync_now'.tr().toUpperCase(),
                        style: DSTypography.button(
                          color: DSColors.white,
                          fontSize: 10.0,
                        ).copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 3.seconds,
                      color: DSColors.white.withValues(alpha: 0.25),
                      delay: 3.seconds,
                    );
                  },
                ),
              // Chevron navigates to sync history — separate tap target.
              IconButton(
                onPressed: () => context.push('/sync'),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? DSColors.white : DSColors.labelPrimary,
                  size: DSIconSize.md,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
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
              child: ScanButton(
                label: 'dashboard.actions.dispatch_action'.tr(),
                details: 'dashboard.actions.dispatch_subtitle'.tr(),
                icon: Icons.qr_code_scanner_rounded,
                color: DSColors.accent,
                onTap: () => context.push('/scan', extra: {'mode': 'dispatch'}),
              ),
            ),
            DSSpacing.wMd,
            Expanded(
              child: ScanButton(
                label: 'dashboard.actions.pod_action'.tr(),
                details: 'dashboard.actions.pod_subtitle'.tr(),
                icon: Icons.camera_alt_rounded,
                color: DSColors.primary,
                onTap: () => context.push('/scan', extra: {'mode': 'pod'}),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Pulsing Connection Indicator ──────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.connStatus});

  final ConnectionStatus connStatus;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.connStatus) {
      ConnectionStatus.online => DSColors.success,
      ConnectionStatus.apiUnreachable => DSColors.warning,
      ConnectionStatus.networkOffline => DSColors.error,
    };

    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.8).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.6, end: 0.0).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
