import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import 'package:fsi_courier_app/core/models/delivery_update_entry.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/sync/sync_manager.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  @override
  void initState() {
    super.initState();
    // Populate the list when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncManagerProvider.notifier).loadEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncManagerProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      appBar: AppHeaderBar(
        title: 'Sync',
        actions: kDebugMode &&
                syncState.entries.any(
                  (e) => e.syncStatus == SyncStatus.failed,
                )
            ? [
                TextButton.icon(
                  onPressed: () =>
                      ref.read(syncManagerProvider.notifier).clearFailed(),
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Clear Failed',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          _SyncHeader(syncState: syncState, isOnline: isOnline),
          Expanded(
            child: syncState.entries.isEmpty
                ? _EmptyState(isSyncing: syncState.isSyncing)
                : _EntryList(syncState: syncState),
          ),
        ],
      ),
      floatingActionButton: _SyncFab(syncState: syncState, isOnline: isOnline),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SyncHeader extends StatelessWidget {
  const _SyncHeader({required this.syncState, required this.isOnline});

  final SyncState syncState;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final synced = syncState.entries
        .where((e) => e.syncStatus == SyncStatus.synced)
        .length;
    final total = syncState.entries.length;
    final pending = syncState.entries
        .where((e) => e.syncStatus == SyncStatus.pending)
        .length;
    final failed = syncState.entries
        .where((e) => e.syncStatus == SyncStatus.failed)
        .length;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connectivity pill
          Row(
            children: [
              Icon(
                isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                size: 16,
                color: isOnline ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isOnline ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (syncState.isSyncing) ...[
            const SizedBox(height: 8),
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
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: syncState.total > 0
                  ? syncState.processed / syncState.total
                  : null,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
          if (total > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$synced of $total synced'
              '${pending > 0 ? ' · $pending pending' : ''}'
              '${failed > 0 ? ' · $failed failed' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Entry List ────────────────────────────────────────────────────────────────

class _EntryList extends ConsumerWidget {
  const _EntryList({required this.syncState});

  final SyncState syncState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = syncState.entries;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _EntryTile(
          entry: entry,
          isSyncing:
              syncState.isSyncing &&
              syncState.currentBarcode == entry.barcode,
          onRetry: entry.syncStatus == SyncStatus.failed
              ? () => ref
                    .read(syncManagerProvider.notifier)
                    .retrySingle(entry.id!)
              : null,
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.isSyncing,
    this.onRetry,
  });

  final DeliveryUpdateEntry entry;
  final bool isSyncing;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('MMM d, h:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
    );

    return ListTile(
      leading: _StatusChip(
        status: entry.syncStatus,
        isSyncing: isSyncing,
      ),
      title: Text(
        entry.barcode,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: theme.textTheme.bodySmall),
          if (entry.errorMessage != null)
            Text(
              entry.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: onRetry != null
          ? TextButton(
              onPressed: onRetry,
              child: const Text('RETRY'),
            )
          : null,
      isThreeLine: entry.errorMessage != null,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isSyncing});

  final SyncStatus status;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    if (isSyncing) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final (color, icon) = switch (status) {
      SyncStatus.pending => (Colors.amber.shade700, Icons.schedule_rounded),
      SyncStatus.syncing => (Colors.blue, Icons.sync_rounded),
      SyncStatus.synced => (Colors.green, Icons.check_circle_rounded),
      SyncStatus.failed => (Colors.red, Icons.error_rounded),
    };

    return Icon(icon, color: color, size: 22);
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isSyncing});

  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isSyncing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/anim/hour-glass.json',
              width: 160,
              height: 160,
              repeat: true,
            ),
            const SizedBox(height: 16),
            Text('Syncing…', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/anim/successfully-done.json',
              width: 180,
              height: 180,
              repeat: false,
            ),
            const SizedBox(height: 16),
            Text(
              'All caught up!',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No pending deliveries to sync.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────

class _SyncFab extends ConsumerWidget {
  const _SyncFab({required this.syncState, required this.isOnline});

  final SyncState syncState;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPending = syncState.entries.any(
      (e) =>
          e.syncStatus == SyncStatus.pending ||
          e.syncStatus == SyncStatus.failed,
    );
    final canSync = isOnline && !syncState.isSyncing && hasPending;

    return FloatingActionButton.extended(
      onPressed: canSync
          ? () => ref.read(syncManagerProvider.notifier).processQueue()
          : null,
      icon: syncState.isSyncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.sync_rounded),
      label: Text(
        syncState.isSyncing
            ? 'Syncing…'
            : (isOnline ? 'Sync Now' : 'Connect to sync'),
      ),
      backgroundColor: canSync ? null : Colors.grey.shade400,
    );
  }
}
