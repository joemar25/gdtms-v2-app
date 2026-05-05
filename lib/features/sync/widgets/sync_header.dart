import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/sync_progress_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'sync_now_button.dart';

class SyncHeader extends ConsumerStatefulWidget {
  const SyncHeader({super.key, required this.connectionStatus});

  final ConnectionStatus connectionStatus;

  @override
  ConsumerState<SyncHeader> createState() => _SyncHeaderState();
}

class _SyncHeaderState extends ConsumerState<SyncHeader> {
  @override
  Widget build(BuildContext context) {
    final lastSyncTime = ref.watch(lastSyncTimeProvider);
    final syncState = ref.watch(syncManagerProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);
    final hasPending = pendingCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DSHeroCard(
          margin: EdgeInsets.symmetric(
            horizontal: DSSpacing.md,
            vertical: DSSpacing.sm,
          ),
          accentColor: hasPending && !syncState.isSyncing
              ? DSColors.warning
              : DSColors.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          syncState.isSyncing
                              ? 'sync.actions.syncing'.tr()
                              : hasPending
                              ? 'sync.status.pending_changes'.tr(
                                  namedArgs: {'count': '$pendingCount'},
                                )
                              : 'sync.status.up_to_date'.tr(),
                          style: DSTypography.heading(
                            color: DSColors.white,
                          ).copyWith(fontSize: 18),
                        ),
                        DSSpacing.hXs,
                        Text(
                          lastSyncTime != null
                              ? 'sync.status.last_sync'.tr(
                                  args: [
                                    formatEpoch(
                                      lastSyncTime.millisecondsSinceEpoch,
                                    ),
                                  ],
                                )
                              : 'sync.status.never_synced'.tr(),
                          style: DSTypography.caption(
                            color: DSColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    syncState.isSyncing
                        ? Icons.sync_rounded
                        : hasPending
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_done_outlined,
                    color: DSColors.white,
                    size: 32,
                  ),
                ],
              ),
              DSSpacing.hMd,
              Row(
                children: [
                  // ── Online Status Badge ──────────────────────────────────
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: DSSpacing.sm,
                      vertical: DSSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: DSColors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(DSStyles.radiusSM),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (widget.connectionStatus) {
                              ConnectionStatus.online => DSColors.success,
                              ConnectionStatus.apiUnreachable =>
                                DSColors.warning,
                              ConnectionStatus.networkOffline => DSColors.error,
                            },
                            boxShadow: [
                              if (widget.connectionStatus ==
                                  ConnectionStatus.online)
                                BoxShadow(
                                  color: DSColors.success.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 4,
                                ),
                            ],
                          ),
                        ),
                        DSSpacing.wSm,
                        Text(
                          switch (widget.connectionStatus) {
                            ConnectionStatus.online =>
                              'sync.status.online'.tr(),
                            ConnectionStatus.apiUnreachable =>
                              'sync.status.api_unreachable'.tr(),
                            ConnectionStatus.networkOffline =>
                              'sync.status.offline'.tr(),
                          },
                          style: DSTypography.label(
                            color: DSColors.white,
                          ).copyWith(fontSize: 10, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              DSSpacing.hMd,
              if (syncState.isSyncing) ...[
                const SyncProgressBar(padding: EdgeInsets.zero),
                DSSpacing.hSm,
              ],
              _RetentionTimer(syncState: syncState),
            ],
          ),
        ),
        DSSectionHeader(
          title: 'sync.list.history_title'.tr(),
          trailing: SyncNowButton(
            isOnline: widget.connectionStatus == ConnectionStatus.online,
          ),
        ),
      ],
    );
  }
}

class _RetentionTimer extends ConsumerStatefulWidget {
  const _RetentionTimer({required this.syncState});
  final SyncState syncState;

  @override
  ConsumerState<_RetentionTimer> createState() => _RetentionTimerState();
}

class _RetentionTimerState extends ConsumerState<_RetentionTimer> {
  bool _eligibleCleanupTriggered = false;

  @override
  Widget build(BuildContext context) {
    final synced = widget.syncState.entries
        .where((e) => e.status == 'synced')
        .map((e) => e.createdAt)
        .toList();
    final int? earliestSynced = synced.isEmpty
        ? null
        : synced.reduce((a, b) => a < b ? a : b);

    return FutureBuilder<int>(
      future: ref.read(appSettingsProvider).getSyncRetentionDays(),
      builder: (context, snap) {
        final int? days = snap.data;
        if (days == null) return const SizedBox.shrink();

        final retentionLabel = days <= 0
            ? '1 min (debug)'
            : '$days day${days == 1 ? '' : 's'}';

        if (earliestSynced == null) {
          return Text(
            'sync.status.retention_days'.tr(args: [retentionLabel]),
            style: DSTypography.caption(
              color: DSColors.white.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          );
        }

        final int expiryMs;
        if (days <= 0) {
          expiryMs = earliestSynced + const Duration(minutes: 1).inMilliseconds;
        } else {
          final created = DateTime.fromMillisecondsSinceEpoch(earliestSynced);
          final creationDay = DateTime(
            created.year,
            created.month,
            created.day,
          );
          expiryMs = creationDay
              .add(Duration(days: days))
              .millisecondsSinceEpoch;
        }

        return StreamBuilder<int>(
          stream: Stream.periodic(
            const Duration(seconds: 1),
            (_) => DateTime.now().millisecondsSinceEpoch,
          ),
          builder: (context, nowSnap) {
            final nowMs = nowSnap.data ?? DateTime.now().millisecondsSinceEpoch;
            final remaining = expiryMs - nowMs;

            if (remaining <= 0 && !_eligibleCleanupTriggered) {
              _eligibleCleanupTriggered = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted) return;
                await ref.read(syncManagerProvider.notifier).loadEntries();
                if (mounted) setState(() => _eligibleCleanupTriggered = false);
              });
            }

            String label;
            if (remaining <= 0) {
              label = 'sync.status.retention_eligible'.tr();
            } else {
              final d = Duration(milliseconds: remaining);
              final dd = d.inDays;
              final hh = d.inHours % 24;
              final mm = d.inMinutes % 60;
              final ss = d.inSeconds % 60;
              String timeStr = dd > 0
                  ? '${dd}d ${hh}h ${mm}m'
                  : hh > 0
                  ? '${hh}h ${mm}m ${ss}s'
                  : mm > 0
                  ? '${mm}m ${ss}s'
                  : '${ss}s';
              label = 'sync.status.retention_remaining'.tr(args: [timeStr]);
            }

            return Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 12,
                  color: DSColors.white.withValues(alpha: 0.7),
                ),
                DSSpacing.wSm,
                Text(
                  label,
                  style: DSTypography.caption(
                    color: DSColors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
