import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/sync/sync_manager.dart';

export 'package:fsi_courier_app/core/sync/sync_manager.dart'
    show SyncState, SyncManagerNotifier;

/// The primary sync manager provider.
///
/// Watch [syncManagerProvider] to observe sync state.
/// Read [syncManagerProvider.notifier] to trigger [processQueue] or [retrySingle].
final syncManagerProvider =
    NotifierProvider<SyncManagerNotifier, SyncState>(SyncManagerNotifier.new);

/// Number of [pending] entries in the sync queue.
/// Useful for displaying a badge on the Sync nav item.
final pendingSyncCountProvider = Provider<int>((ref) {
  final entries = ref.watch(syncManagerProvider).entries;
  return entries.where((e) => e.status == 'pending' || e.status == 'processing' || e.status == 'error' || e.status == 'failed' || e.status == 'conflict').length;
});

/// The timestamp of the last successful full sync.
class _LastSyncTimeNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setValue(DateTime? value) => state = value;
}

final lastSyncTimeProvider =
    NotifierProvider<_LastSyncTimeNotifier, DateTime?>(_LastSyncTimeNotifier.new);
