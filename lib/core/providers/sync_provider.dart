// DOCS: docs/development-standards.md
// DOCS: docs/core/providers.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/sync/sync_manager.dart';

export 'package:fsi_courier_app/core/sync/sync_manager.dart'
    show SyncState, SyncManagerNotifier;

/// The primary sync manager provider.
///
/// Watch [syncManagerProvider] to observe sync state.
/// Read [syncManagerProvider.notifier] to trigger [requestFlush], [processQueue],
/// or [retrySingle]. Prefer [requestFlush] for coalesced queue kicks (A8).
/// For post-write side effects (queue + list refresh), use
/// `syncWriteCoordinatorProvider` (A2) in `lib/core/sync/sync_write_coordinator.dart`.
final syncManagerProvider = NotifierProvider<SyncManagerNotifier, SyncState>(
  SyncManagerNotifier.new,
);

/// Number of [pending] entries in the sync queue.
/// Useful for displaying a badge on the Sync nav item.
final pendingSyncCountProvider = Provider<int>((ref) {
  final entries = ref.watch(syncManagerProvider).entries;
  final actionable = entries.where(
    (e) =>
        e.status == 'pending' ||
        e.status == 'processing' ||
        e.status == 'error' ||
        e.status == 'failed' ||
        e.status == 'conflict',
  );

  // Group by barcode for Bagsakan items to match the "collapsed" UI logic.
  final seenBagsakan = <String>{};
  int count = 0;
  for (final e in actionable) {
    if (e.barcode.startsWith('BAGSAKAN_')) {
      if (!seenBagsakan.contains(e.barcode)) {
        seenBagsakan.add(e.barcode);
        count++;
      }
    } else {
      count++;
    }
  }
  return count;
});

/// Number of [synced] entries in the sync history.
/// Grouped by barcode to match the "collapsed" UI logic.
final syncedSyncCountProvider = Provider<int>((ref) {
  final entries = ref.watch(syncManagerProvider).entries;
  final synced = entries.where((e) => e.status == 'synced');

  final seenBagsakan = <String>{};
  int count = 0;
  for (final e in synced) {
    if (e.barcode.startsWith('BAGSAKAN_')) {
      if (!seenBagsakan.contains(e.barcode)) {
        seenBagsakan.add(e.barcode);
        count++;
      }
    } else {
      count++;
    }
  }
  return count;
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
