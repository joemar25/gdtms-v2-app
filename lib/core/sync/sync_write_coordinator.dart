// DOCS: docs/development-standards.md
// DOCS: docs/core/sync.md — update that file when you edit this one.
// DOCS: docs/architecture/system-map.md

// =============================================================================
// sync_write_coordinator.dart
// =============================================================================
//
// Shared post-write side effects (ARCHITECTURE A2):
//   kick offline queue (coalesced via requestFlush) + optional list refresh.
// Feature screens should call [completeWrite] after enqueuing local work instead
// of hand-rolling processQueue / deliveryRefreshProvider.increment pairs.
//
// Production-safe: does not change payloads, offline queue schema, or
// reconciliation rules — only unifies when flush/refresh run after a write.
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';

/// Coordinates side effects after a feature write (queue insert, local update).
class SyncWriteCoordinator {
  SyncWriteCoordinator(this._ref);

  final Ref _ref;

  /// After local work is persisted, optionally flush the offline queue and/or
  /// bump [deliveryRefreshProvider].
  ///
  /// - [kickQueue]: when true and online, call coalesced [SyncManagerNotifier.requestFlush].
  /// - [awaitIdle]: wait for flush to finish (bagsakan online save, Sync screen).
  ///   UI delivery submit typically uses `false` so navigation is snappy.
  /// - [refreshDeliveries]: invalidate delivery lists (debounced; A3).
  /// - [barcodes]: optional scope for invalidation (null/empty = full refresh).
  /// - [reason]: diagnostic label for `[SYNC] requestFlush` logs.
  Future<void> completeWrite({
    bool kickQueue = true,
    bool awaitIdle = false,
    bool refreshDeliveries = true,
    Set<String>? barcodes,
    String reason = 'write',
  }) async {
    if (kickQueue && _ref.read(isOnlineProvider)) {
      await _ref
          .read(syncManagerProvider.notifier)
          .requestFlush(reason: reason, awaitIdle: awaitIdle);
    }

    if (refreshDeliveries) {
      _ref
          .read(deliveryRefreshProvider.notifier)
          .invalidate(barcodes: barcodes);
    }
  }
}

/// Global write side-effect helper (ARCHITECTURE A2).
final syncWriteCoordinatorProvider = Provider<SyncWriteCoordinator>((ref) {
  return SyncWriteCoordinator(ref);
});
