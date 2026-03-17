import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';

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
    final theme = Theme.of(context);

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
        padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: effectivePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (syncState.isSyncing) ...[
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    syncState.lastMessage ?? 'Syncing…',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: syncState.total > 0
                  ? syncState.processed / syncState.total
                  : null,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            ),
          ] else ...[
            Row(
              children: [
                Icon(
                  isOnline
                      ? Icons.cloud_sync_outlined
                      : Icons.cloud_off_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  [
                    if (pending > 0) '$pending pending',
                    if (failed > 0) '$failed failed',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: failed > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
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
