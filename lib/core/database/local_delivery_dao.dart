import 'dart:convert';

import 'package:flutter/foundation.dart';
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
        'delivery_status': status.toUpperCase(),
        'updated_at': now,
        if (status.toUpperCase() == 'DELIVERED') 'delivered_at': now,
        if (status.toUpperCase() == 'DELIVERED' || status.toUpperCase() == 'RTS' || status.toUpperCase() == 'OSA')
          'completed_at': now,
        'sync_status': 'dirty',
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
    // Always uppercase — server returns UPPERCASE (e.g. 'DELIVERED').
    // All DAO queries filter on uppercase values; storing lowercase makes
    // the record invisible to countVisibleDelivered / getVisibleDeliveredPaged
    // until the next syncFromApi pass overwrites it.
    final status =
        (json['status']?.toString() ??
            json['deliveryStatus']?.toString() ??
            json['delivery_status']?.toString() ??
            'PENDING').toUpperCase();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Parse is_paid from the fresh API response (v2.0 field).
    // Sentinel 1 = historically paid; only set when not already a real timestamp.
    final isPaid = json['is_paid'] as bool? ?? false;

    // Get existing raw_json to merge
    final existing = await getByBarcode(barcode);
    final existingJson = existing?.toDeliveryMap() ?? {};
    final mergedJson = {...existingJson, ...json};

    // Parse rts_verification_status from fresh API response.
    final rtsVerifStatus =
        json['rts_verification_status']?.toString() ??
        existing?.rtsVerificationStatus;

    await db.update(
      'local_deliveries',
      {
        'delivery_status': status,
        'recipient_name':
            json['name']?.toString() ??
            json['recipient_name']?.toString() ??
            existing?.recipientName,
        'delivery_address':
            json['address']?.toString() ??
            json['delivery_address']?.toString() ??
            existing?.deliveryAddress,
        'raw_json': jsonEncode(mergedJson),
        'updated_at': now,
        if (status == 'DELIVERED' || status == 'RTS' || status == 'OSA')
          'completed_at': now,
        // Server confirmed this record — mark clean so insertAllFromApiItems
        // no longer treats it as a dirty/unsynced courier update.
        'sync_status': 'clean',
        if (rtsVerifStatus != null)
          'rts_verification_status': rtsVerifStatus,
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
    if (status == 'DELIVERED') {
      // Only use delivered_date — transaction_at is the package creation date,
      // not the delivery completion date. Using it would push delivered_at
      // to a past date and exclude the item from the today-filter.
      final dateStr = json['delivered_date']?.toString();
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
    String serverStatus = 'PENDING',
  }) async {
    debugPrint('[DAO] insertAllFromApiItems: ${items.length} items, status=$serverStatus');
    final db = await _db;

    // Collect all local records so we can decide what to do per-item.
    final existingRows = await db.query(
      'local_deliveries',
      columns: ['barcode', 'sync_status'],
    );
    final syncStatusByBarcode = <String, String?>{
      for (final row in existingRows)
        row['barcode'] as String: row['sync_status'] as String?,
    };

    final terminalStatuses = {'DELIVERED', 'RTS', 'OSA'};
    final batch = db.batch();
    final serverStatusUpper = serverStatus.toUpperCase();

    for (final json in items) {
      final delivery = LocalDelivery.fromApiItem(
        json,
        dispatchCode: dispatchCode,
        serverStatus: serverStatusUpper,
      );
      if (delivery.barcode.isEmpty) continue;

      final syncStatus = syncStatusByBarcode[delivery.barcode];
      final isDirty = syncStatus == 'dirty';
      final isServerTerminal = terminalStatuses.contains(serverStatusUpper);

      if (isDirty) {
        // Rule: Never overwrite status of dirty (unsynced courier update).
        // Clean terminal records CAN be updated by the server (e.g. web admin correction).
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
            'delivery_status': serverStatusUpper,
            'raw_json': delivery.rawJson,
            'updated_at': delivery.updatedAt,
            if (delivery.deliveredAt != null)
              'delivered_at': delivery.deliveredAt,
            if (delivery.completedAt != null)
              'completed_at': delivery.completedAt,
            // Always refresh so pay-status badge stays current without
            // requiring a full re-insert (ConflictAlgorithm.ignore skips it).
            'rts_verification_status': delivery.rtsVerificationStatus,
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
    final totalRows = await db.rawQuery('SELECT COUNT(*) as c FROM local_deliveries');
    debugPrint('[DAO] insertAllFromApiItems done — total rows in DB: ${totalRows.first['c']}');
  }

  // ── Read ──────────────────────────────────────────────────────────────────────────────

  /// Returns the count of deliveries matching [status].
  Future<int> countByStatus(String status) async {
    final db = await _db;
    final res = await db.rawQuery(
      'SELECT COUNT(*) FROM local_deliveries WHERE delivery_status COLLATE NOCASE = ? AND COALESCE(is_archived, 0) = 0',
      [status.toUpperCase()],
    );
    if (status.toUpperCase() == 'PENDING') {
      // Diagnostic: dump distinct statuses and archived counts to trace pending=0.
      final dist = await db.rawQuery(
        "SELECT delivery_status, COALESCE(is_archived,0) as arch, COUNT(*) as n "
        "FROM local_deliveries GROUP BY delivery_status, arch",
      );
      debugPrint('[DAO] countByStatus(pending)=${Sqflite.firstIntValue(res) ?? 0} — breakdown: $dist');
    }
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Returns all barcodes for locally-pending deliveries.
  /// Used by [DeliveryBootstrapService] to identify which items need
  /// priority reconciliation against the server on the next sync.
  Future<Set<String>> getPendingBarcodes() async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      columns: ['barcode'],
      where: "delivery_status COLLATE NOCASE = 'PENDING' AND COALESCE(is_archived, 0) = 0",
    );
    return rows.map((r) => r['barcode'] as String).toSet();
  }

  /// Returns all deliveries with the given [status], ordered by [created_at].
  Future<List<LocalDelivery>> getByStatus(String status) async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      where: 'delivery_status COLLATE NOCASE = ? AND COALESCE(is_archived, 0) = 0',
      whereArgs: [status.toUpperCase()],
      orderBy: 'updated_at DESC',
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
      where: 'delivery_status COLLATE NOCASE = ? AND COALESCE(is_archived, 0) = 0',
      whereArgs: [status.toUpperCase()],
      orderBy: 'updated_at DESC',
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
          "delivery_status COLLATE NOCASE = 'RTS' "
          'AND completed_at >= ? AND completed_at < ? '
          // Exclude all verified RTS items — once verified the courier has no
          // further action to take, so they only clutter the list.
          "AND COALESCE(rts_verification_status, 'unvalidated') NOT IN ('verified_with_pay', 'verified_no_pay') "
          'AND COALESCE(is_archived, 0) = 0',
      whereArgs: [todayStart, tomorrowStart],
      orderBy: 'updated_at DESC',
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
          "delivery_status COLLATE NOCASE = 'OSA' "
          'AND completed_at >= ? AND completed_at < ? '
          'AND COALESCE(is_archived, 0) = 0',
      whereArgs: [todayStart, tomorrowStart],
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Paginated variant of [getVisibleDelivered].
  ///
  /// mar-note: paid items (paid_at > 0) are intentionally excluded.
  /// See [kPaidDeliveryRetentionDays] for the full security/anti-fraud rationale.
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
          "delivery_status COLLATE NOCASE = 'DELIVERED' "
          'AND delivered_at >= ? AND delivered_at < ? '
          // mar-note: exclude paid records — COALESCE(paid_at,0) > 0 means
          // sentinel (1) or real paid timestamp; both must be hidden from
          // the courier's list to prevent double-payout manipulation.
          'AND COALESCE(paid_at, 0) = 0 '
          'AND COALESCE(is_archived, 0) = 0',
      whereArgs: [todayStart, tomorrowStart],
      orderBy: 'updated_at DESC',
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

    String where;
    List<Object?> whereArgs;

    if (status.toUpperCase() == 'DELIVERED') {
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final tomorrowStart =
          DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
      where =
          "(barcode LIKE ? OR recipient_name LIKE ? COLLATE NOCASE) "
          "AND delivery_status COLLATE NOCASE = 'DELIVERED' "
          'AND delivered_at >= ? AND delivered_at < ? '
          // mar-note: for 'delivered' search results, paid records are hidden
          // (COALESCE(paid_at,0)>0). For rts/osa paid_at is always NULL so
          // this filter is a no-op on those statuses — no risk of excluding
          // valid rts/osa items.
          'AND COALESCE(paid_at, 0) = 0 '
          'AND COALESCE(is_archived, 0) = 0';
      whereArgs = [q, q, todayStart, tomorrowStart];
    } else if (status.toUpperCase() == 'RTS' || status.toUpperCase() == 'OSA') {
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final tomorrowStart =
          DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
      where =
          "(barcode LIKE ? OR recipient_name LIKE ? COLLATE NOCASE) "
          "AND delivery_status COLLATE NOCASE = ? "
          'AND completed_at >= ? AND completed_at < ? '
          // Exclude all verified RTS items — once verified the courier can no longer act on them.
          "AND (delivery_status COLLATE NOCASE != 'RTS' OR COALESCE(rts_verification_status, 'unvalidated') NOT IN ('verified_with_pay', 'verified_no_pay')) "
          'AND COALESCE(is_archived, 0) = 0';
      whereArgs = [q, q, status.toUpperCase(), todayStart, tomorrowStart];
    } else {
      where =
          '(barcode LIKE ? OR recipient_name LIKE ? COLLATE NOCASE) AND delivery_status COLLATE NOCASE = ? '
          'AND COALESCE(is_archived, 0) = 0';
      whereArgs = [q, q, status.toUpperCase()];
    }

    final rows = await db.query(
      'local_deliveries',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
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
      where: '(barcode LIKE ? OR recipient_name LIKE ? COLLATE NOCASE) AND COALESCE(is_archived, 0) = 0',
      whereArgs: [q, q],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Variant of [searchByQuery] restricted to deliveries that are currently
  /// visible in one of the courier's active list screens.
  ///
  /// Used by the scan (POD) screen as a UX pre-filter. The single SQL query
  /// mirrors the four buckets of [isVisibleToRider] exactly:
  ///
  ///   • PENDING   — any non-archived pending record
  ///   • DELIVERED — delivered_at is today AND paid_at = 0 (unpaid)
  ///   • RTS       — completed_at is today AND rts_verification_status NOT IN
  ///                 ('verified_with_pay', 'verified_no_pay')
  ///   • OSA       — completed_at is today
  ///
  /// [DeliveryDetailScreen._load] still calls [isVisibleToRider] as the
  /// canonical hard gate — this method is purely a performance and UX
  /// optimisation that avoids an N+1 per-match check in the scan screen.
  Future<List<LocalDelivery>> searchVisibleByQuery(
    String query, {
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) return [];
    final db = await _db;
    final q = '%${query.trim()}%';
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    // NOTE: if you update isVisibleToRider, update this query too — they must
    // stay in sync or the scan pre-filter will diverge from the hard gate.
    final rows = await db.rawQuery(
      '''
      SELECT * FROM local_deliveries
      WHERE (barcode LIKE ? OR recipient_name LIKE ? COLLATE NOCASE)
        AND COALESCE(is_archived, 0) = 0
        AND (
          -- PENDING: any non-archived pending record
          (delivery_status COLLATE NOCASE = 'PENDING')

          -- DELIVERED: today only (paid status does not restrict viewing)
          OR (delivery_status COLLATE NOCASE = 'DELIVERED'
              AND delivered_at  >= $todayStart AND delivered_at  < $tomorrowStart)

          -- RTS: today only, unverified
          OR (delivery_status COLLATE NOCASE = 'RTS'
              AND completed_at >= $todayStart AND completed_at < $tomorrowStart
              AND COALESCE(rts_verification_status, 'unvalidated')
                  NOT IN ('verified_with_pay', 'verified_no_pay'))

          -- OSA: today only
          OR (delivery_status COLLATE NOCASE = 'OSA'
              AND completed_at >= $todayStart AND completed_at < $tomorrowStart)
        )
      ORDER BY updated_at DESC
      LIMIT $limit
      ''',
      [q, q],
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Returns delivered items whose [delivered_at] falls within today
  /// (i.e. transaction_date / delivered_date from the server is today).
  ///
  /// Strictly bounded to [todayStart, tomorrowStart) so only deliveries
  /// with an actual delivery date of today are shown.
  ///
  /// mar-note: paid records (COALESCE(paid_at,0) > 0) are excluded.
  /// Once a payout is confirmed the delivered record has a 1-day lifespan
  /// and must not resurface in the list — prevents couriers from re-claiming
  /// or referencing already-paid deliveries.
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
          "delivery_status COLLATE NOCASE = 'DELIVERED' "
          'AND delivered_at >= ? AND delivered_at < ? '
          'AND COALESCE(paid_at, 0) = 0 '
          'AND COALESCE(is_archived, 0) = 0',
      whereArgs: [todayStart, tomorrowStart],
      orderBy: 'updated_at DESC',
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Returns the count of delivered items whose [delivered_at] is today AND
  /// that have NOT yet been paid.
  ///
  /// mar-note: the dashboard delivered count reflects work the courier can still
  /// request payout for. Paid records (paid_at > 0, either sentinel=1 or real
  /// timestamp) are deliberately excluded:
  ///   • They already appear in wallet/payout history on the server.
  ///   • Their local lifespan is kPaidDeliveryRetentionDays (1 day) — showing
  ///     them in the count would create a phantom number that disappears after
  ///     cleanup, which could confuse or be exploited by the courier.
  Future<int> countVisibleDelivered() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final res = await db.rawQuery(
      'SELECT COUNT(*) FROM local_deliveries '
      'WHERE delivery_status COLLATE NOCASE = "DELIVERED" '
      'AND delivered_at >= ? AND delivered_at < ? '
      'AND COALESCE(paid_at, 0) = 0 '
      'AND COALESCE(is_archived, 0) = 0',
      [todayStart, tomorrowStart],
    );
    final count = Sqflite.firstIntValue(res) ?? 0;
    // Log all delivered rows to diagnose date filter issues
    final allDelivered = await db.rawQuery(
      "SELECT barcode, delivered_at, completed_at FROM local_deliveries WHERE delivery_status COLLATE NOCASE='DELIVERED' LIMIT 5",
    );
    debugPrint('[DAO] countVisibleDelivered: $count today (todayStart=$todayStart)');
    for (final r in allDelivered) {
      debugPrint('[DAO]   barcode=${r['barcode']} delivered_at=${r['delivered_at']} completed_at=${r['completed_at']}');
    }
    return count;
  }

  /// Returns the count of RTS items whose [completed_at] is today.
  Future<int> countVisibleRts() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final res = await db.rawQuery(
      'SELECT COUNT(*) FROM local_deliveries '
      'WHERE delivery_status COLLATE NOCASE = "RTS" '
      'AND completed_at >= ? AND completed_at < ? '
      // Exclude all verified RTS items (with or without pay).
      "AND COALESCE(rts_verification_status, 'unvalidated') NOT IN ('verified_with_pay', 'verified_no_pay') "
      'AND COALESCE(is_archived, 0) = 0',
      [todayStart, tomorrowStart],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Returns the count of OSA items whose [completed_at] is today.
  Future<int> countVisibleOsa() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final res = await db.rawQuery(
      'SELECT COUNT(*) FROM local_deliveries '
      'WHERE delivery_status COLLATE NOCASE = "OSA" '
      'AND completed_at >= ? AND completed_at < ? '
      'AND COALESCE(is_archived, 0) = 0',
      [todayStart, tomorrowStart],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Returns `true` when [barcode] would appear in one of the courier's active
  /// list screens (pending, today-delivered, today-RTS, today-OSA).
  ///
  /// This mirrors the visibility rules of every list query exactly:
  ///
  /// | Status    | Visible when                                                      |
  /// |-----------|-------------------------------------------------------------------|
  /// | PENDING   | Not archived                                                      |
  /// | DELIVERED | delivered_at is today AND paid_at = 0 (unpaid)                    |
  /// | RTS       | completed_at is today AND rts_verification_status is NOT verified |
  /// | OSA       | completed_at is today                                             |
  /// | other     | never visible                                                     |
  ///
  /// Used by the scan screen to gate navigation — a courier must not be able
  /// to open a delivery that is not in their active list.
  Future<bool> isVisibleToRider(String barcode) async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      columns: [
        'delivery_status',
        'delivered_at',
        'completed_at',
        'paid_at',
        'rts_verification_status',
        'is_archived',
      ],
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final row = rows.first;
    final status =
        (row['delivery_status'] as String? ?? '').toUpperCase();
    final isArchived = (row['is_archived'] as int? ?? 0) != 0;
    if (isArchived) return false;

    final now = DateTime.now();
    final todayStart =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;

    switch (status) {
      case 'PENDING':
        return true;

      case 'DELIVERED':
        final deliveredAt = row['delivered_at'] as int? ?? 0;
        return deliveredAt >= todayStart && deliveredAt < tomorrowStart;

      case 'RTS':
        final completedAt = row['completed_at'] as int? ?? 0;
        final rtsVerif =
            (row['rts_verification_status'] as String? ?? 'unvalidated')
                .toLowerCase();
        return completedAt >= todayStart &&
            completedAt < tomorrowStart &&
            rtsVerif != 'verified_with_pay' &&
            rtsVerif != 'verified_no_pay';

      case 'OSA':
        final completedAt = row['completed_at'] as int? ?? 0;
        return completedAt >= todayStart && completedAt < tomorrowStart;

      default:
        return false;
    }
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

    // Only operate on locally-pending records that are NOT dirty.
    final pendingRows = await db.query(
      'local_deliveries',
      columns: ['barcode'],
      where: "delivery_status COLLATE NOCASE = 'PENDING' AND COALESCE(sync_status, '') != 'dirty'",
    );

    final staleBarcodes = pendingRows
        .map((r) => r['barcode'] as String)
        .where((b) => !serverBarcodes.contains(b))
        .toList();

    if (staleBarcodes.isEmpty) return;

    // Set is_archived = 1 in batches to stay within SQLite parameter limits.
    const chunkSize = 50;
    for (var i = 0; i < staleBarcodes.length; i += chunkSize) {
      final chunk = staleBarcodes.skip(i).take(chunkSize).toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      await db.update(
        'local_deliveries',
        {'is_archived': 1},
        where: "barcode IN ($placeholders) AND delivery_status COLLATE NOCASE = 'PENDING'",
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
  /// mar-note: TWO separate deletions run here:
  ///   1. Unpaid completed records older than retentionMs (3 days default).
  ///   2. Paid records older than paidRetentionMs (1 day).
  ///
  /// After either deletion, [getByBarcode] returns null for that barcode.
  /// This is intentional: a courier scanning or navigating to a paid+expired
  /// barcode finds nothing — preventing re-submission, double-payout attempts,
  /// or viewing of the recipient's personal data after the payout is settled.
  Future<int> deleteOldSynced(int retentionMs, {required int paidRetentionMs}) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - retentionMs;
    final paidCutoff = now - paidRetentionMs;

    // Delete standard (unpaid) completed records past standard retention.
    final countUnpaid = await db.delete(
      'local_deliveries',
      where:
          "delivery_status IN ('delivered', 'rts', 'osa') "
          "AND paid_at IS NULL "
          "AND updated_at < ?",
      whereArgs: [cutoff],
    );

    // mar-note: paid records use paidCutoff (1-day window) — much shorter than
    // the unpaid window. This aggressively removes settled deliveries to close
    // the manipulation window as quickly as possible.
    final countPaid = await db.delete(
      'local_deliveries',
      where:
          "delivery_status IN ('delivered', 'rts', 'osa') "
          "AND paid_at IS NOT NULL "
          "AND paid_at < ?",
      whereArgs: [paidCutoff],
    );

    return countUnpaid + countPaid;
  }
}
