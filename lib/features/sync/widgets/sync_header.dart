import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/sync_progress_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class SyncHeader extends ConsumerStatefulWidget {
  const SyncHeader({super.key, required this.isOnline});

  final bool isOnline;

  @override
  ConsumerState<SyncHeader> createState() => _SyncHeaderState();
}

class _SyncHeaderState extends ConsumerState<SyncHeader> {
  bool _eligibleCleanupTriggered = false;

  @override
  Widget build(BuildContext context) {
    final lastSyncTime = ref.watch(lastSyncTimeProvider);
    final syncState = ref.watch(syncManagerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: Theme.of(context).brightness == Brightness.dark
              ? DSColors.scaffoldDark
              : DSColors.scaffoldLight,
          padding: EdgeInsets.fromLTRB(
            DSSpacing.md,
            DSSpacing.md,
            DSSpacing.md,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.isOnline
                        ? Icons.wifi_rounded
                        : Icons.wifi_off_rounded,
                    size: DSIconSize.sm,
                    color: widget.isOnline
                        ? DSColors.success
                        : DSColors.warning,
                  ),
                  DSSpacing.wXs,
                  Text(
                    widget.isOnline
                        ? 'sync.status.online'.tr()
                        : 'sync.status.offline'.tr(),
                    style: DSTypography.label(
                      color:
                          widget.isOnline ? DSColors.success : DSColors.warning,
                    ).copyWith(fontSize: DSTypography.sizeSm),
                  ),
                ],
              ),
              if (lastSyncTime != null) ...[
                DSSpacing.hXs,
                Text(
                  'sync.status.last_sync'.tr(args: [
                    formatEpoch(lastSyncTime.millisecondsSinceEpoch),
                  ]),
                  style: DSTypography.caption(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? DSColors.labelSecondaryDark
                        : DSColors.labelSecondary,
                  ).copyWith(fontSize: DSTypography.sizeXs),
                ),
              ],

              Builder(
                builder: (ctx) {
                  final synced = syncState.entries
                      .where((e) => e.status == 'synced')
                      .map((e) => e.createdAt)
                      .toList();
                  final int? earliestSynced = synced.isEmpty
                      ? null
                      : synced.reduce((a, b) => a < b ? a : b);

                  return FutureBuilder<int>(
                    future: ref
                        .read(appSettingsProvider)
                        .getSyncRetentionDays(),
                    builder: (context, snap) {
                      final int? days = snap.data;
                      if (days == null) {
                        return const SizedBox.shrink();
                      }

                      final retentionLabel = days <= 0
                          ? '1 min (debug)'
                          : '$days day${days == 1 ? '' : 's'}';

                      if (earliestSynced == null) {
                        return Padding(
                          padding: EdgeInsets.only(top: DSSpacing.sm),
                          child: Text(
                            'sync.status.retention_days'.tr(
                              args: [retentionLabel],
                            ),
                            style: DSTypography.caption(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? DSColors.labelSecondaryDark
                                  : DSColors.labelSecondary,
                            ).copyWith(fontSize: DSTypography.sizeXs),
                          ),
                        );
                      }

                      final int expiryMs;
                      if (days <= 0) {
                        expiryMs =
                            earliestSynced +
                            const Duration(minutes: 1).inMilliseconds;
                      } else {
                        final created = DateTime.fromMillisecondsSinceEpoch(
                          earliestSynced,
                        );
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
                          final nowMs =
                              nowSnap.data ??
                              DateTime.now().millisecondsSinceEpoch;
                          final remaining = expiryMs - nowMs;

                          if (remaining <= 0 && !_eligibleCleanupTriggered) {
                            _eligibleCleanupTriggered = true;
                            WidgetsBinding.instance.addPostFrameCallback((
                              _,
                            ) async {
                              if (!mounted) return;
                              await ref
                                  .read(syncManagerProvider.notifier)
                                  .loadEntries();
                              if (mounted) {
                                setState(
                                  () => _eligibleCleanupTriggered = false,
                                );
                              }
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
                            String timeStr;
                            if (dd > 0) {
                              timeStr = '${dd}d ${hh}h ${mm}m';
                            } else if (hh > 0) {
                              timeStr = '${hh}h ${mm}m ${ss}s';
                            } else if (mm > 0) {
                              timeStr = '${mm}m ${ss}s';
                            } else {
                              timeStr = '${ss}s';
                            }
                            label = 'sync.status.retention_remaining'.tr(
                              args: [timeStr],
                            );
                          }

                          return Padding(
                            padding: EdgeInsets.only(top: DSSpacing.sm),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: DSIconSize.xs,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? DSColors.labelSecondaryDark
                                      : DSColors.labelSecondary,
                                ),
                                DSSpacing.wSm,
                                Text(
                                  label,
                                  style: DSTypography.caption(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? DSColors.labelSecondaryDark
                                        : DSColors.labelSecondary,
                                  ).copyWith(fontSize: DSTypography.sizeXs),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              DSSpacing.hMd,
            ],
          ),
        ),
        const SyncProgressBar(
          padding: EdgeInsets.symmetric(
            horizontal: DSSpacing.md,
            vertical: DSSpacing.sm,
          ),
        ),
      ],
    );
  }
}
