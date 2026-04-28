// DOCS: docs/development-standards.md
// DOCS: docs/shared/widgets.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Inline sync status bar for use inside a screen's own layout.
///
/// Shows a spinner + progress while syncing, or a pending/failed summary when
/// idle with unresolved queue entries. Returns [SizedBox.shrink] when the
/// queue is clear and no sync is in progress.
///
/// Used:
///  - in [SyncScreen]'s header
///  - in [DeliveryUpdateScreen]'s initial loading placeholder
///
/// For the app-wide floating indicator see [_SyncFloatingPill] in app.dart.
class SyncProgressBar extends ConsumerWidget {
  const SyncProgressBar({super.key, this.padding});

  /// Optional padding override. Defaults to a compact horizontal/vertical inset.
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncManagerProvider);
    final isOnline = ref.watch(isOnlineProvider);

    final pending = syncState.entries
        .where((e) => e.status == 'pending' || e.status == 'processing')
        .length;
    final failed = syncState.entries
        .where(
          (e) =>
              e.status == 'error' ||
              e.status == 'failed' ||
              e.status == 'conflict',
        )
        .length;

    final hasActivity = syncState.isSyncing || pending > 0 || failed > 0;
    if (!hasActivity) return const SizedBox.shrink();

    final effectivePadding =
        padding ??
        EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: DSSpacing.sm);

    return Container(
      width: double.infinity,
      color: Theme.of(context).brightness == Brightness.dark
          ? DSColors.scaffoldDark
          : DSColors.scaffoldLight,
      padding: effectivePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (syncState.isSyncing) ...[
            Row(
              children: [
                const SizedBox(
                  width: DSIconSize.sm,
                  height: DSIconSize.sm,
                  child: CircularProgressIndicator(
                    strokeWidth: DSStyles.strokeWidth,
                  ),
                ),
                DSSpacing.wSm,
                Expanded(
                  child: Text(
                    syncState.lastMessage ?? 'Syncing…',
                    style: DSTypography.caption(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? DSColors.labelPrimaryDark
                          : DSColors.labelPrimary,
                    ).copyWith(fontSize: DSTypography.sizeSm),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            DSSpacing.hXs,
            LinearProgressIndicator(
              value: syncState.total > 0
                  ? syncState.processed / syncState.total
                  : null,
              minHeight: 3,
              borderRadius: DSStyles.pillRadius,
            ),
          ] else ...[
            Row(
              children: [
                Icon(
                  isOnline
                      ? Icons.cloud_sync_outlined
                      : Icons.cloud_off_outlined,
                  size: DSIconSize.xs,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
                ),
                DSSpacing.wSm,
                Text(
                  [
                    if (pending > 0) '$pending pending',
                    if (failed > 0) '$failed failed',
                  ].join(' · '),
                  style:
                      DSTypography.caption(
                        color: failed > 0
                            ? DSColors.error
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? DSColors.labelSecondaryDark
                                  : DSColors.labelSecondary),
                      ).copyWith(
                        fontSize: DSTypography.sizeSm,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
