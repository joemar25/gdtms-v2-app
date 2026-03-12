import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';

/// Data access object for the [local_deliveries] table.
class LocalDeliveryDao {
  const LocalDeliveryDao._();

  static const LocalDeliveryDao instance = LocalDeliveryDao._();

  Future<Database> get _db => AppDatabase.getInstance();

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Inserts (or replaces) the delivery objects from the eligibility response
  /// into local storage, binding them to the accepting [dispatchCode].
  ///
  /// Deliveries with no resolvable barcode are silently skipped.
  Future<void> insertAll(
    List<Map<String, dynamic>> deliveries, {
    required String dispatchCode,
  }) async {
    final db = await _db;
    final batch = db.batch();
    for (final json in deliveries) {
      final delivery = LocalDelivery.fromJson(
        json,
        dispatchCode: dispatchCode,
      );
      if (delivery.barcode.isEmpty) continue;
      batch.insert(
        'local_deliveries',
        delivery.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Updates only [delivery_status] and [updated_at] for the given [barcode].
  /// Used for optimistic local updates when a rider submits offline.
  Future<void> updateStatus(String barcode, String status) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'local_deliveries',
      {
        'delivery_status': status,
        'updated_at': now,
        if (status == 'delivered') 'delivered_at': now,
        if (status == 'delivered' || status == 'rts' || status == 'osa')
          'completed_at': now,
      },
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

  /// Refreshes a record's indexed fields and [rawJson] from a fresh API response.
  /// Called after a successful GET or PATCH while online.
  Future<void> updateFromJson(
    String barcode,
    Map<String, dynamic> json,
  ) async {
    final db = await _db;
    final status = json['delivery_status']?.toString() ?? 'pending';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Parse is_paid from the fresh API response (v2.0 field).
    // Sentinel 1 = historically paid; only set when not already a real timestamp.
    final isPaid = json['is_paid'] as bool? ?? false;

    await db.update(
      'local_deliveries',
      {
        'delivery_status': status,
        'recipient_name':
            json['name']?.toString() ?? json['recipient_name']?.toString(),
        'delivery_address':
            json['address']?.toString() ??
            json['delivery_address']?.toString(),
        'raw_json': jsonEncode(json),
        'updated_at': now,
        if (status == 'delivered' || status == 'rts' || status == 'osa')
          'completed_at': now,
      },
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    // Update paid_at sentinel when API reports is_paid=true but local record
    // has no real payout timestamp yet.
    if (isPaid) {
      await db.rawUpdate(
        'UPDATE local_deliveries SET paid_at = COALESCE(NULLIF(paid_at, 0), 1) WHERE barcode = ? AND (paid_at IS NULL OR paid_at <= 1)',
        [barcode],
      );
    }

    // Preserve the original delivered_at — prefer the server's delivered_date,
    // fall back to transaction_at, then now. COALESCE keeps the earlier value
    // on subsequent syncs so the timestamp is never overwritten.
    if (status == 'delivered') {
      final dateStr =
          json['delivered_date']?.toString() ??
          json['transaction_at']?.toString();
      int deliveredAt = now;
      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          deliveredAt = DateTime.parse(dateStr).millisecondsSinceEpoch;
        } catch (_) {
          deliveredAt = now;
        }
      }
      await db.rawUpdate(
        'UPDATE local_deliveries SET delivered_at = COALESCE(delivered_at, ?) WHERE barcode = ?',
        [deliveredAt, barcode],
      );
    }
  }

  /// Inserts (or replaces) delivery items from the `GET /deliveries` API response.
  /// Uses [LocalDelivery.fromApiItem] which tolerates both eligibility-response
  /// field names and delivery-API field names.
  ///
  /// ## Reconciliation Rules
  ///
  /// - If the SERVER returns an item with a *terminal* status (`delivered`, `rts`,
  ///   `osa`) the local record is **always** updated so that manual web-app
  ///   status changes are reflected on the mobile device.
  ///
  /// - If the SERVER returns an item with a *pending* status, local terminal
  ///   records are **not** downgraded (prevents a courier's confirmed delivery
  ///   from reverting to pending during a background sync).
  ///
  /// - `delivered_at` and `completed_at` timestamps are always corrected from
  ///   the server-provided date fields so the today-filter works accurately.
  ///
  /// [serverStatus] — the status bucket this batch was fetched from (e.g.
  /// `'pending'`, `'delivered'`). Pass it so the DAO can apply the right rule.
  Future<void> insertAllFromApiItems(
    List<Map<String, dynamic>> items, {
    String dispatchCode = '',
    String serverStatus = 'pending',
  }) async {
    final db = await _db;

    // Collect all local records so we can decide what to do per-item.
    final existingRows = await db.query(
      'local_deliveries',
      columns: ['barcode', 'delivery_status'],
    );
    final localStatusByBarcode = <String, String>{
      for (final row in existingRows)
        row['barcode'] as String: row['delivery_status'] as String,
    };

    final terminalStatuses = {'delivered', 'rts', 'osa'};
    final batch = db.batch();

    for (final json in items) {
      final delivery = LocalDelivery.fromApiItem(
        json,
        dispatchCode: dispatchCode,
      );
      if (delivery.barcode.isEmpty) continue;

      final localStatus = localStatusByBarcode[delivery.barcode];
      final isLocalTerminal =
          localStatus != null && terminalStatuses.contains(localStatus);
      final isServerTerminal = terminalStatuses.contains(serverStatus);

      if (isLocalTerminal && !isServerTerminal) {
        // Rule: Never downgrade a terminal local record to pending.
        // Only correct timestamps if available.
        if (delivery.deliveredAt != null || delivery.completedAt != null) {
          batch.update(
            'local_deliveries',
            {
              if (delivery.deliveredAt != null)
                'delivered_at': delivery.deliveredAt,
              if (delivery.completedAt != null)
                'completed_at': delivery.completedAt,
            },
            where: 'barcode = ?',
            whereArgs: [delivery.barcode],
          );
        }
        continue;
      }

      // If it is terminal on the server, we always want the server's state
      // (either it's a new terminal state, or upgrading from pending to terminal).
      if (isServerTerminal) {
        batch.update(
          'local_deliveries',
          {
            'delivery_status': serverStatus,
            'raw_json': delivery.rawJson,
            'updated_at': delivery.updatedAt,
            if (delivery.deliveredAt != null)
              'delivered_at': delivery.deliveredAt,
            if (delivery.completedAt != null)
              'completed_at': delivery.completedAt,
          },
          where: 'barcode = ?',
          whereArgs: [delivery.barcode],
        );
        // If the row didn't exist at all, the update above does nothing, so we
        // also insert — but only for genuinely new rows (IGNORE keeps existing
        // rows untouched, preserving dispatch_code, created_at, paid_at, etc.).
        batch.insert(
          'local_deliveries',
          delivery.toDb(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        continue;
      }

      // Default for pending items: upsert the record (new item or same-status update).
      // Since it's pending on the server, it's safe to replace.
      batch.insert(
        'local_deliveries',
        delivery.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ── Read ──────────────────────────────────────────────────────────────────────────────

  /// Returns the count of deliveries matching [status].
  Future<int> countByStatus(String status) async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      columns: ['id'],
      where: 'delivery_status = ?',
      whereArgs: [status],
    );
    return rows.length;
  }

  /// Returns all barcodes for locally-pending deliveries.
  /// Used by [DeliveryBootstrapService] to identify which items need
  /// priority reconciliation against the server on the next sync.
  Future<Set<String>> getPendingBarcodes() async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      columns: ['barcode'],
      where: "delivery_status = 'pending'",
    );
    return rows.map((r) => r['barcode'] as String).toSet();
  }

  /// Returns all deliveries with the given [status], ordered by [created_at].
  Future<List<LocalDelivery>> getByStatus(String status) async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      where: 'delivery_status = ?',
      whereArgs: [status],
      orderBy: 'created_at ASC',
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Paginated variant of [getByStatus].
  Future<List<LocalDelivery>> getByStatusPaged(
    String status, {
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      where: 'delivery_status = ?',
      whereArgs: [status],
      orderBy: 'created_at ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Paginated variant of [getVisibleRts].
  Future<List<LocalDelivery>> getVisibleRtsPaged({
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      where:
          "delivery_status = 'rts' "
          'AND completed_at >= ? AND completed_at < ?',
      whereArgs: [todayStart, tomorrowStart],
      orderBy: 'completed_at DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Paginated variant of [getVisibleOsa].
  Future<List<LocalDelivery>> getVisibleOsaPaged({
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      where:
          "delivery_status = 'osa' "
          'AND completed_at >= ? AND completed_at < ?',
      whereArgs: [todayStart, tomorrowStart],
      orderBy: 'completed_at DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Paginated variant of [getVisibleDelivered].
  Future<List<LocalDelivery>> getVisibleDeliveredPaged({
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      where:
          "delivery_status = 'delivered' "
          'AND delivered_at >= ? AND delivered_at < ?',
      whereArgs: [todayStart, tomorrowStart],
      orderBy: 'delivered_at DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Searches deliveries by [query] filtered to a specific [status].
  /// For the 'delivered' status, restricts to today's range.
  Future<List<LocalDelivery>> searchByStatusAndQuery(
    String status,
    String query, {
    int limit = 300,
  }) async {
    if (query.trim().isEmpty) return [];
    final db = await _db;
    final q = '%${query.trim()}%';
    if (status == 'delivered' || status == 'rts' || status == 'osa') {
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final tomorrowStart =
          DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
      final rows = await db.query(
        'local_deliveries',
        where:
            "(barcode LIKE ? OR recipient_name LIKE ?) "
            'AND delivery_status = ? '
            'AND completed_at >= ? AND completed_at < ?',
        whereArgs: [q, q, status, todayStart, tomorrowStart],
        orderBy: 'completed_at DESC, created_at DESC',
        limit: limit,
      );
      return rows.map(LocalDelivery.fromDb).toList();
    }
    final rows = await db.query(
      'local_deliveries',
      where:
          '(barcode LIKE ? OR recipient_name LIKE ?) AND delivery_status = ?',
      whereArgs: [q, q, status],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Returns the delivery matching [barcode], or `null` if not found.
  Future<LocalDelivery?> getByBarcode(String barcode) async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LocalDelivery.fromDb(rows.first);
  }

  /// Searches all deliveries whose [barcode] or [recipient_name] contains
  /// [query] (case-insensitive substring match). Returns up to [limit] results
  /// ordered by created_at ASC.
  Future<List<LocalDelivery>> searchByQuery(
    String query, {
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) return [];
    final db = await _db;
    final q = '%${query.trim()}%';
    final rows = await db.query(
      'local_deliveries',
      where: 'barcode LIKE ? OR recipient_name LIKE ?',
      whereArgs: [q, q],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Returns delivered items whose [delivered_at] falls within today
  /// (i.e. transaction_date / delivered_date from the server is today).
  ///
  /// Strictly bounded to [todayStart, tomorrowStart) so only deliveries
  /// with an actual delivery date of today are shown.
  Future<List<LocalDelivery>> getVisibleDelivered() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      where:
          "delivery_status = 'delivered' "
          'AND delivered_at >= ? AND delivered_at < ?',
      whereArgs: [todayStart, tomorrowStart],
      orderBy: 'delivered_at DESC, created_at DESC',
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Returns the count of delivered items whose [completed_at] is today.
  /// Used by the dashboard offline fallback to match the server's
  /// today-only [delivered_today] figure.
  Future<int> countVisibleDelivered() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      columns: ['id'],
      where:
          "delivery_status = 'delivered' "
          'AND delivered_at >= ? AND delivered_at < ?',
      whereArgs: [todayStart, tomorrowStart],
    );
    return rows.length;
  }

  /// Returns the count of RTS items whose [completed_at] is today.
  Future<int> countVisibleRts() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      columns: ['id'],
      where:
          "delivery_status = 'rts' "
          'AND completed_at >= ? AND completed_at < ?',
      whereArgs: [todayStart, tomorrowStart],
    );
    return rows.length;
  }

  /// Returns the count of OSA items whose [completed_at] is today.
  Future<int> countVisibleOsa() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      columns: ['id'],
      where:
          "delivery_status = 'osa' "
          'AND completed_at >= ? AND completed_at < ?',
      whereArgs: [todayStart, tomorrowStart],
    );
    return rows.length;
  }

  /// Deletes ALL rows from [local_deliveries].
  /// Used by [DeliveryBootstrapService.clearAndSyncFromApi] to force a fresh
  /// load from the server (e.g. "Reload from Server" action on Sync screen).
  Future<void> deleteAll() async {
    final db = await _db;
    await db.delete('local_deliveries');
  }

  /// Removes locally-pending items whose barcodes are NOT present in
  /// [serverBarcodes] — the full set returned by the server across all
  /// status pages during the latest sync cycle.
  ///
  /// This cleans up deliveries that a web-app admin cancelled, reassigned,
  /// or otherwise removed from the courier's workload since the last sync.
  ///
  /// Items in a terminal state (`delivered`, `rts`, `osa`) are never removed
  /// by this method — they are kept for payout and history purposes.
  Future<void> removeStaleLocalPending(Set<String> serverBarcodes) async {
    if (serverBarcodes.isEmpty) return;
    final db = await _db;

    // Only operate on locally-pending records.
    final pendingRows = await db.query(
      'local_deliveries',
      columns: ['barcode'],
      where: "delivery_status = 'pending'",
    );

    final staleBarcodes = pendingRows
        .map((r) => r['barcode'] as String)
        .where((b) => !serverBarcodes.contains(b))
        .toList();

    if (staleBarcodes.isEmpty) return;

    // Delete in batches to stay within SQLite parameter limits.
    const chunkSize = 50;
    for (var i = 0; i < staleBarcodes.length; i += chunkSize) {
      final chunk = staleBarcodes.skip(i).take(chunkSize).toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      await db.delete(
        'local_deliveries',
        where: "barcode IN ($placeholders) AND delivery_status = 'pending'",
        whereArgs: chunk,
      );
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Marks the given [barcodes] as paid by setting [paid_at] to now.
  ///
  /// Called when a payout request transitions to the "paid" status so that
  /// the cleanup service can apply the shorter [kPaidDeliveryRetentionDays]
  /// window to these records instead of the standard [kLocalDataRetentionDays].
  Future<void> markAsPaid(List<String> barcodes) async {
    if (barcodes.isEmpty) return;
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    for (final barcode in barcodes) {
      batch.update(
        'local_deliveries',
        {'paid_at': now},
        where: 'barcode = ? AND (paid_at IS NULL OR paid_at <= 1)',
        whereArgs: [barcode],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Deletes completed delivery records older than [retentionMs] milliseconds.
  /// Only `delivered`, `rts`, and `osa` records are eligible.
  /// `pending` records are never deleted.
  ///
  /// Privacy rule — paid deliveries use a shorter window ([paidRetentionMs]):
  /// once a delivery belongs to a paid payout ([paid_at] IS NOT NULL) it is
  /// kept for only [kPaidDeliveryRetentionDays] day before deletion, regardless
  /// of the standard [retentionMs].
  Future<void> deleteOldSynced(int retentionMs, {required int paidRetentionMs}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - retentionMs;
    final paidCutoff = now - paidRetentionMs;

    // Delete standard (unpaid) completed records past standard retention.
    await db.delete(
      'local_deliveries',
      where:
          "delivery_status IN ('delivered', 'rts', 'osa') "
          "AND paid_at IS NULL "
          "AND updated_at < ?",
      whereArgs: [cutoff],
    );

    // Delete paid records past the shorter paid retention window.
    await db.delete(
      'local_deliveries',
      where:
          "delivery_status IN ('delivered', 'rts', 'osa') "
          "AND paid_at IS NOT NULL "
          "AND paid_at < ?",
      whereArgs: [paidCutoff],
    );
  }
}
