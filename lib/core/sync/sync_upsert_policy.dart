// DOCS: docs/development-standards.md
// DOCS: docs/core/sync.md
// DOCS: docs/architecture/accuracy-and-scale.md

/// Pure upsert decisions used by [LocalDeliveryDao.insertAllFromApiItems].
///
/// Kept free of SQLite so production accuracy rules are unit-tested without a DB.
class SyncUpsertPolicy {
  const SyncUpsertPolicy._();

  /// P5: skip rewriting a clean row when server `data_checksum` matches local.
  ///
  /// Returns `false` (must write) when:
  /// - row is dirty (courier offline update — Rule 2 path must still run), or
  /// - either checksum is missing/empty (unknown → safer to write), or
  /// - checksums differ (real server change).
  static bool shouldSkipUnchangedChecksum({
    required bool isDirty,
    required String? existingChecksum,
    required String? incomingChecksum,
  }) {
    if (isDirty) return false;
    final incoming = incomingChecksum?.trim() ?? '';
    final existing = existingChecksum?.trim() ?? '';
    if (incoming.isEmpty || existing.isEmpty) return false;
    return incoming == existing;
  }
}

/// Pure paging helpers for delivery list sync (P1/P2).
class DeliverySyncPaging {
  const DeliverySyncPaging._();

  /// Pages to fetch after page 1 when the API reports [lastPage].
  static List<int> remainingPages(int lastPage) {
    if (lastPage <= 1) return const [];
    return [for (var p = 2; p <= lastPage; p++) p];
  }

  /// Split [pages] into concurrent batches of size [concurrency] (min 1).
  static List<List<int>> chunkPages(List<int> pages, int concurrency) {
    final size = concurrency < 1 ? 1 : concurrency;
    if (pages.isEmpty) return const [];
    final out = <List<int>>[];
    for (var i = 0; i < pages.length; i += size) {
      out.add(pages.sublist(i, i + size > pages.length ? pages.length : i + size));
    }
    return out;
  }

  /// Expected number of GET /deliveries list calls for one status with [lastPage]
  /// pages when using page-1-then-chunked remaining pages.
  static int expectedListCallsForStatus(int lastPage) {
    if (lastPage < 1) return 0;
    return lastPage;
  }
}
