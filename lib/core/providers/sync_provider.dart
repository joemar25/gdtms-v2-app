// DOCS: docs/development-standards.md
// DOCS: docs/core/providers.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/sync/sync_manager.dart';

export 'package:fsi_courier_app/core/sync/sync_manager.dart'
    show SyncState, SyncManagerNotifier;

/// The primary sync manager provider.
///
/// Watch [syncManagerProvider] to observe sync state.
/// Read [syncManagerProvider.notifier] to trigger [processQueue] or [retrySingle].
final syncManagerProvider = NotifierProvider<SyncManagerNotifier, SyncState>(
  SyncManagerNotifier.new,
);

/// Number of [pending] entries in the sync queue.
/// Useful for displaying a badge on the Sync nav item.
final pendingSyncCountProvider = Provider<int>((ref) {
  final entries = ref.watch(syncManagerProvider).entries;
  return entries
      .where(
        (e) =>
            e.status == 'pending' ||
            e.status == 'processing' ||
            e.status == 'error' ||
            e.status == 'failed' ||
            e.status == 'conflict',
      )
      .length;
});

/// A map of barcode to count of FAILED_DELIVERY status updates in the sync queue.
/// Used to determine if a delivery is locked due to maximum retry attempts.
final failedDeliveryCountsProvider = Provider<Map<String, int>>((ref) {
  final entries = ref.watch(syncManagerProvider).entries;
  final counts = <String, int>{};

  for (final e in entries) {
    if (e.operationType != 'UPDATE_STATUS') continue;
    try {
      // ignore: avoid_dynamic_calls
      final status =
          e.payload['delivery_status']?.toString().toUpperCase() ?? '';
      if (status == 'FAILED_DELIVERY') {
        counts[e.barcode] = (counts[e.barcode] ?? 0) + 1;
      }
    } catch (_) {}
  }
  return counts;
});

/// The timestamp of the last successful full sync.
class _LastSyncTimeNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setValue(DateTime? value) => state = value;
}

final lastSyncTimeProvider = NotifierProvider<_LastSyncTimeNotifier, DateTime?>(
  _LastSyncTimeNotifier.new,
);
