// DOCS: docs/development-standards.md
// DOCS: docs/core/database.md — update that file when you edit this one.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';

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
    String? tat,
    String? transmittalDate,
  }) async {
    final db = await _db;
    final batch = db.batch();
    for (final json in deliveries) {
      final delivery = LocalDelivery.fromJson(
        json,
        dispatchCode: dispatchCode,
        tat: tat,
        transmittalDate: transmittalDate,
      );
      if (delivery.barcode.isEmpty) continue;

      if (delivery.failedDeliveryVerifEnum.isVerified) {
        debugPrint(
          '[DAO] Purging verified item during insertAll: ${delivery.barcode}',
        );
        batch.delete(
          'local_deliveries',
          where: 'barcode COLLATE NOCASE = ?',
          whereArgs: [delivery.barcode],
        );
        continue;
      }

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
        if (status.toUpperCase() == 'DELIVERED' ||
            status.toUpperCase() == 'FAILED_DELIVERY' ||
            status.toUpperCase() == 'OSA')
          'completed_at': now,
        'sync_status': 'dirty',
      },
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

  /// Refreshes a record's indexed fields and [rawJson] from a fresh API response.
  /// Called after a successful GET or PATCH while online.
  Future<void> updateFromJson(String barcode, Map<String, dynamic> json) async {
    final db = await _db;
    // Always uppercase — server returns UPPERCASE (e.g. 'DELIVERED').
    // All DAO queries filter on uppercase values; storing lowercase makes
    // the record invisible to countVisibleDelivered / getVisibleDeliveredPaged
    // until the next syncFromApi pass overwrites it.
    final status = (json['delivery_status']?.toString() ?? 'FOR_DELIVERY')
        .toUpperCase();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Parse rts_verification_status from fresh API response.
    // Get existing raw_json to merge
    final existing = await getByBarcode(barcode);
    final existingJson = existing?.toDeliveryMap() ?? {};
    final mergedJson = {...existingJson, ...json};

    // Parse rts_verification_status from fresh API response.
    final failedDeliveryVerifStatus =
        json['rts_verification_status']?.toString() ??
        existing?.rtsVerificationStatus;

    final values = <String, dynamic>{
      'delivery_status': status,
      'mail_type': json['mail_type']?.toString() ?? existing?.mailType,
      'product': json['product']?.toString() ?? existing?.product,
      'recipient_name':
          json['recipient_name']?.toString() ?? existing?.recipientName,
      'delivery_address':
          json['recipient_address']?.toString() ?? existing?.deliveryAddress,
      'raw_json': jsonEncode(mergedJson),
      'updated_at': now,
      'sync_status': 'clean',
      'piece_count': json['piece_count'] as int? ?? existing?.pieceCount ?? 1,
      'piece_index': json['piece_index'] as int? ?? existing?.pieceIndex ?? 1,
      'allowed_statuses': jsonEncode(
        (json['allowed_statuses'] as List?)?.cast<String>() ??
            existing?.allowedStatuses ??
            const [],
      ),
      'data_checksum':
          json['data_checksum']?.toString() ?? existing?.dataChecksum,
    };

    if (status == 'DELIVERED' ||
        status == 'FAILED_DELIVERY' ||
        status == 'OSA') {
      values['completed_at'] = now;
    }

    // Rule: if the record is now verified (RTS), purge it from local DB immediately.
    // Verified items are no longer part of the courier's active workload and must
    // be removed to ensure they cannot be accessed or viewed again.
    final verifEnum = FailedDeliveryVerificationStatus.fromString(
      failedDeliveryVerifStatus,
    );
    if (verifEnum.isVerified) {
      debugPrint('[DAO] Purging verified item during updateFromJson: $barcode');
      await db.delete(
        'local_deliveries',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );
      return;
    }

    if (failedDeliveryVerifStatus != null) {
      values['rts_verification_status'] = failedDeliveryVerifStatus;
    }

    await db.update(
      'local_deliveries',
      values,
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

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
        final parsedDate = parseServerDate(dateStr);
        if (parsedDate != null) {
          deliveredAt = parsedDate.millisecondsSinceEpoch;
        } else {
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
  /// - If the SERVER returns an item with a *terminal* status (`delivered`,
  ///   `failed_delivery`, `osa`) the local record is **always** updated so that
  ///   manual web-app status changes are reflected on the mobile device.
  ///
  /// - If the SERVER returns an item with a *pending* status, local terminal
  ///   records are **not** downgraded (prevents a courier's confirmed delivery
  ///   from reverting to pending during a background sync).
  ///
  /// - `delivered_at` and `completed_at` timestamps are always corrected from
  ///   the server-provided date fields so the today-filter works accurately.
  ///
  /// [serverStatus] — the status bucket this batch was fetched from (e.g.
  /// `'FOR_DELIVERY'`, `'DELIVERED'`, `'FAILED_DELIVERY'`). Pass it so the DAO can apply the right rule.
  Future<void> insertAllFromApiItems(
    List<Map<String, dynamic>> items, {
    String dispatchCode = '',
    String serverStatus = 'FOR_DELIVERY',
  }) async {
    debugPrint(
      '[DAO] insertAllFromApiItems: ${items.length} items, status=$serverStatus',
    );
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

    final terminalStatuses = {'DELIVERED', 'FAILED_DELIVERY', 'OSA'};
    final batch = db.batch();
    final serverStatusUpper = serverStatus.toUpperCase();

    for (final json in items) {
      final delivery = LocalDelivery.fromApiItem(
        json,
        dispatchCode: dispatchCode,
        serverStatus: serverStatusUpper,
      );
      if (delivery.barcode.isEmpty) continue;

      // Special rule: if the server reports it as verified (RTS), it must be purged
      // immediately. Verified items are no longer part of the courier's active workload.
      if (delivery.failedDeliveryVerifEnum.isVerified) {
        debugPrint(
          '[DAO] Purging verified item during sync: ${delivery.barcode}',
        );
        batch.delete(
          'local_deliveries',
          where: 'barcode = ?',
          whereArgs: [delivery.barcode],
        );
        continue;
      }

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
            'delivery_status': delivery.deliveryStatus,
            'mail_type': delivery.mailType,
            'product': delivery.product,
            'raw_json': delivery.rawJson,
            'updated_at': delivery.updatedAt,
            if (delivery.deliveredAt != null)
              'delivered_at': delivery.deliveredAt,
            if (delivery.completedAt != null)
              'completed_at': delivery.completedAt,
            // Always refresh so pay-status badge stays current without
            // requiring a full re-insert (ConflictAlgorithm.ignore skips it).
            'rts_verification_status': delivery.rtsVerificationStatus,
            'piece_count': delivery.pieceCount,
            'piece_index': delivery.pieceIndex,
            'allowed_statuses': jsonEncode(delivery.allowedStatuses),
            'data_checksum': delivery.dataChecksum,
          },
          where: 'barcode = ?',
          whereArgs: [delivery.barcode],
        );
        // If the row didn't exist at all, the update above does nothing, so we
        // also insert — but only for genuinely new rows (IGNORE keeps existing
        // rows untouched, preserving dispatch_code, created_at, etc.).
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
    final totalRows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM local_deliveries',
    );
    debugPrint(
      '[DAO] insertAllFromApiItems done — total rows in DB: ${totalRows.first['c']}',
    );
  }

  // ── Read ──────────────────────────────────────────────────────────────────────────────

  /// Returns the count of deliveries matching [status].
  Future<int> countByStatus(String status) async {
    final db = await _db;
    final res = await db.rawQuery(
      'SELECT COUNT(*) FROM local_deliveries WHERE delivery_status COLLATE NOCASE = ? AND COALESCE(is_archived, 0) = 0',
      [status.toUpperCase()],
    );
    if (status.toUpperCase() == 'FOR_DELIVERY') {
      // Diagnostic: dump distinct statuses and archived counts to trace pending=0.
      final dist = await db.rawQuery(
        "SELECT delivery_status, COALESCE(is_archived,0) as arch, COUNT(*) as n "
        "FROM local_deliveries GROUP BY delivery_status, arch",
      );
      debugPrint(
        '[DAO] countByStatus(pending)=${Sqflite.firstIntValue(res) ?? 0} — breakdown: $dist',
      );
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
      where:
          "delivery_status COLLATE NOCASE IN ('FOR_DELIVERY') AND COALESCE(is_archived, 0) = 0",
    );
    return rows.map((r) => r['barcode'] as String).toSet();
  }

  /// Returns all deliveries with the given [status], ordered by [created_at].
  Future<List<LocalDelivery>> getByStatus(String status) async {
    final db = await _db;
    final rows = await db.query(
      'local_deliveries',
      where:
          'delivery_status COLLATE NOCASE = ? AND COALESCE(is_archived, 0) = 0',
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
      where:
          'delivery_status COLLATE NOCASE = ? AND COALESCE(is_archived, 0) = 0',
      whereArgs: [status.toUpperCase()],
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Paginated variant of [getVisibleFailedDelivery].
  Future<List<LocalDelivery>> getVisibleFailedDeliveryPaged({
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      where:
          "delivery_status COLLATE NOCASE = 'FAILED_DELIVERY' "
          "AND completed_at >= ? AND completed_at < ? "
          "AND COALESCE(rts_verification_status, 'unvalidated') COLLATE NOCASE NOT IN ('verified_with_pay', 'verified_no_pay') "
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
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;
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
  Future<List<LocalDelivery>> getVisibleDeliveredPaged({
    int limit = 30,
    int offset = 0,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      where:
          "delivery_status COLLATE NOCASE = 'DELIVERED' "
          'AND delivered_at >= ? AND delivered_at < ? '
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
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).millisecondsSinceEpoch;
      final tomorrowStart = DateTime(
        now.year,
        now.month,
        now.day + 1,
      ).millisecondsSinceEpoch;
      where =
          "(barcode LIKE ? OR recipient_name LIKE ? COLLATE NOCASE) "
          "AND delivery_status COLLATE NOCASE = 'DELIVERED' "
          'AND delivered_at >= ? AND delivered_at < ? '
          'AND COALESCE(is_archived, 0) = 0';
      whereArgs = [q, q, todayStart, tomorrowStart];
    } else if (status.toUpperCase() == 'FAILED_DELIVERY') {
      final now = DateTime.now();
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).millisecondsSinceEpoch;
      final tomorrowStart = DateTime(
        now.year,
        now.month,
        now.day + 1,
      ).millisecondsSinceEpoch;
      where =
          "(barcode LIKE ? OR recipient_name LIKE ? COLLATE NOCASE) "
          "AND delivery_status COLLATE NOCASE = 'FAILED_DELIVERY' "
          'AND completed_at >= ? AND completed_at < ? '
          // Exclude verified failed-delivery items — once verified the courier can no longer act.
          "AND COALESCE(rts_verification_status, 'unvalidated') COLLATE NOCASE NOT IN ('verified_with_pay', 'verified_no_pay') "
          'AND COALESCE(is_archived, 0) = 0';
      whereArgs = [q, q, todayStart, tomorrowStart];
    } else if (status.toUpperCase() == 'OSA') {
      final now = DateTime.now();
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).millisecondsSinceEpoch;
      final tomorrowStart = DateTime(
        now.year,
        now.month,
        now.day + 1,
      ).millisecondsSinceEpoch;
      where =
          "(barcode LIKE ? OR recipient_name LIKE ? COLLATE NOCASE) "
          "AND delivery_status COLLATE NOCASE = ? "
          'AND completed_at >= ? AND completed_at < ? '
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
      where: 'barcode COLLATE NOCASE = ?',
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
      where:
          '(barcode LIKE ? COLLATE NOCASE OR recipient_name LIKE ? COLLATE NOCASE) AND COALESCE(is_archived, 0) = 0',
      whereArgs: [q, q],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Variant of [searchByQuery] restricted to deliveries that are actionable
  /// for delivery — PENDING or unverified FAILED_DELIVERY only.
  ///
  /// Used by the scan (POD) screen as a UX pre-filter. DELIVERED and OSA are
  /// intentionally excluded: they are not valid delivery targets.
  ///
  ///   - `PENDING`          — any non-archived pending record
  ///   - `FAILED_DELIVERY` (RTS) — completed_at is today AND
  ///     rts_verification_status is NOT verified AND attempts < 3
  ///
  /// OSA, DELIVERED, and RTS with 3+ attempts are intentionally excluded —
  /// those are terminal states the courier cannot act on via POD scan.
  ///
  /// [DeliveryUpdateScreen._load] still calls [isVisibleToRider] as the
  /// canonical hard gate — this method is purely a performance and UX
  /// optimisation that avoids an N+1 per-match check in the scan screen.
  Future<List<LocalDelivery>> searchVisibleByQuery(
    String query, {
    int limit = 30,
  }) async {
    if (query.trim().isEmpty) return [];
    final db = await _db;
    final q = '%${query.trim()}%';
    final rows = await db.rawQuery(
      '''
      SELECT * FROM local_deliveries
      WHERE (barcode LIKE ? COLLATE NOCASE OR recipient_name LIKE ? COLLATE NOCASE)
        AND COALESCE(is_archived, 0) = 0
        AND (
          -- FOR_DELIVERY: any non-archived pending record
          (delivery_status COLLATE NOCASE IN ('FOR_DELIVERY','FOR_REDELIVERY'))

          -- FAILED_DELIVERY: include unverified failed deliveries (attempts >= 3 are
          -- excluded by the Dart post-filter below because attempts live in raw_json).
          OR (delivery_status COLLATE NOCASE = 'FAILED_DELIVERY'
              AND COALESCE(rts_verification_status, 'unvalidated') COLLATE NOCASE NOT IN ('verified_with_pay', 'verified_no_pay'))
        )
      ORDER BY updated_at DESC
      LIMIT $limit
      ''',
      [q, q],
    );

    final deliveries = rows.map(LocalDelivery.fromDb).toList();

    // Post-filter: exclude RTS with 3+ attempts.
    // OSA and DELIVERED are already excluded by the SQL WHERE clause.
    return deliveries.where((d) {
      if (d.deliveryStatus.toUpperCase() != 'FAILED_DELIVERY') return true;
      return getAttemptsCountFromMap(d.toDeliveryMap()) < 3;
    }).toList();
  }

  /// Returns delivered items whose [delivered_at] falls within today
  /// (i.e. transaction_date / delivered_date from the server is today).
  ///
  /// Strictly bounded to [todayStart, tomorrowStart) so only deliveries
  /// with an actual delivery date of today are shown.
  ///
  /// and must not resurface in the list.
  Future<List<LocalDelivery>> getVisibleDelivered() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;
    final rows = await db.query(
      'local_deliveries',
      where:
          "delivery_status COLLATE NOCASE = 'DELIVERED' "
          'AND delivered_at >= ? AND delivered_at < ? '
          'AND COALESCE(is_archived, 0) = 0',
      whereArgs: [todayStart, tomorrowStart],
      orderBy: 'updated_at DESC',
    );
    return rows.map(LocalDelivery.fromDb).toList();
  }

  /// Returns the count of delivered items whose [delivered_at] is today AND
  /// that have NOT yet been paid.
  ///
  /// request payout for.
  Future<int> countVisibleDelivered() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;
    final res = await db.rawQuery(
      'SELECT COUNT(*) FROM local_deliveries '
      "WHERE delivery_status COLLATE NOCASE = 'DELIVERED' "
      'AND delivered_at >= ? AND delivered_at < ? '
      'AND COALESCE(is_archived, 0) = 0',
      [todayStart, tomorrowStart],
    );
    final count = Sqflite.firstIntValue(res) ?? 0;
    // Log all delivered rows to diagnose date filter issues
    final allDelivered = await db.rawQuery(
      "SELECT barcode, delivered_at, completed_at FROM local_deliveries WHERE delivery_status COLLATE NOCASE='DELIVERED' LIMIT 5",
    );
    debugPrint(
      '[DAO] countVisibleDelivered: $count today (todayStart=$todayStart)',
    );
    for (final r in allDelivered) {
      debugPrint(
        '[DAO]   barcode=${r['barcode']} delivered_at=${r['delivered_at']} completed_at=${r['completed_at']}',
      );
    }
    return count;
  }

  /// Returns the count of failed-delivery items whose [completed_at] is today.
  Future<int> countVisibleFailedDelivery() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;
    final res = await db.rawQuery(
      "SELECT COUNT(*) FROM local_deliveries "
      "WHERE delivery_status COLLATE NOCASE = 'FAILED_DELIVERY' "
      'AND completed_at >= ? AND completed_at < ? '
      // Exclude all verified failed-delivery items (with or without pay).
      "AND COALESCE(rts_verification_status, 'unvalidated') COLLATE NOCASE NOT IN ('verified_with_pay', 'verified_no_pay') "
      'AND COALESCE(is_archived, 0) = 0',
      [todayStart, tomorrowStart],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Returns the count of OSA items whose [completed_at] is today.
  Future<int> countVisibleOsa() async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;
    final res = await db.rawQuery(
      'SELECT COUNT(*) FROM local_deliveries '
      "WHERE delivery_status COLLATE NOCASE = 'OSA' "
      'AND completed_at >= ? AND completed_at < ? '
      'AND COALESCE(is_archived, 0) = 0',
      [todayStart, tomorrowStart],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Returns `true` when [barcode] would appear in one of the courier's active
  /// list screens (pending, today-delivered, today-FAILED_DELIVERY, today-OSA).
  ///
  /// This mirrors the visibility rules of every list query exactly:
  ///
  /// | Status    | Visible when                                                      |
  /// |-----------|-------------------------------------------------------------------|
  /// | PENDING          | Not archived                                                      |
  /// | DELIVERED        | delivered_at is today                                             |
  /// | FAILED_DELIVERY  | completed_at is today AND rts_verification_status is NOT verified |
  /// | OSA              | completed_at is today                                             |
  /// | other     | never visible                                                     |
  ///
  /// Used by the scan screen to gate navigation — a courier must not be able
  /// to open a delivery that is not in their active list.
  Future<bool> isVisibleToRider(String barcode) async {
    final db = await _db;
    // SELECT * so that LocalDelivery.fromDb() (used for attempt-count parsing
    // in the failedDelivery case) receives every column it expects.
    final rows = await db.query(
      'local_deliveries',
      where: 'barcode COLLATE NOCASE = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) {
      debugPrint('[DAO] isVisibleToRider($barcode) -> NO ROW');
      return false;
    }

    final row = rows.first;
    final statusStr = (row['delivery_status'] as String? ?? '').toUpperCase();
    final isArchived = (row['is_archived'] as int? ?? 0) != 0;
    if (isArchived) {
      debugPrint('[DAO] isVisibleToRider($barcode) -> archived=1');
      return false;
    }

    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final tomorrowStart = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;

    final ds = DeliveryStatus.fromString(statusStr);

    switch (ds) {
      case DeliveryStatus.pending:
        debugPrint('[DAO] isVisibleToRider($barcode) -> pending -> true');
        return true;

      case DeliveryStatus.delivered:
        final deliveredAt = row['delivered_at'] as int? ?? 0;
        final visible =
            deliveredAt >= todayStart && deliveredAt < tomorrowStart;
        debugPrint(
          '[DAO] isVisibleToRider($barcode) -> delivered_at=$deliveredAt visible=$visible',
        );
        return visible;

      case DeliveryStatus.failedDelivery:
        final failedDeliveryVerif =
            (row['rts_verification_status'] as String? ?? 'unvalidated')
                .toLowerCase();
        if (failedDeliveryVerif == 'verified_with_pay' ||
            failedDeliveryVerif == 'verified_no_pay') {
          debugPrint(
            '[DAO] isVisibleToRider($barcode) -> failedDelivery verif=$failedDeliveryVerif -> false',
          );
          return false;
        }
        try {
          final ld = LocalDelivery.fromDb(row);
          final attempts = getAttemptsCountFromMap(ld.toDeliveryMap());
          final visible = attempts < 3;
          debugPrint(
            '[DAO] isVisibleToRider($barcode) -> failedDelivery attempts=$attempts visible=$visible',
          );
          return visible;
        } catch (e) {
          debugPrint(
            '[DAO] isVisibleToRider($barcode) -> failedDelivery parse error: $e',
          );
          return false;
        }

      case DeliveryStatus.osa:
        final completedAt = row['completed_at'] as int? ?? 0;
        final visible =
            completedAt >= todayStart && completedAt < tomorrowStart;
        debugPrint(
          '[DAO] isVisibleToRider($barcode) -> OSA completed_at=$completedAt visible=$visible',
        );
        return visible;

      default:
        debugPrint(
          '[DAO] isVisibleToRider($barcode) -> default false for statusStr=$statusStr',
        );
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
  /// Items in a terminal success state (`DELIVERED`) are usually kept for payout
  /// tracking, but `FAILED_DELIVERY` and `OSA` are included in cleanup because
  /// they are purged once verified or reassigned by the hub.
  Future<void> removeStaleLocalPending(Set<String> serverBarcodes) async {
    if (serverBarcodes.isEmpty) return;
    final db = await _db;

    // Only operate on locally-pending records that are NOT dirty.
    final pendingRows = await db.query(
      'local_deliveries',
      columns: ['barcode'],
      where:
          "delivery_status COLLATE NOCASE IN ('FOR_DELIVERY', 'FAILED_DELIVERY', 'OSA') AND COALESCE(sync_status, '') != 'dirty'",
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
        where:
            "barcode IN ($placeholders) AND delivery_status COLLATE NOCASE IN ('FOR_DELIVERY')",
        whereArgs: chunk,
      );
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<int> deleteOldSynced(int retentionMs) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - retentionMs;

    // Skip any barcode that still has an unresolved sync operation so that
    // captured photos and delivery data are never lost before a successful sync.
    final count = await db.rawDelete(
      "DELETE FROM local_deliveries "
      "WHERE delivery_status COLLATE NOCASE IN ('DELIVERED', 'FAILED_DELIVERY', 'OSA') "
      "AND updated_at < ? "
      "AND barcode NOT IN ("
      "  SELECT DISTINCT barcode FROM sync_operations "
      "  WHERE status IN ('pending', 'processing', 'failed', 'conflict')"
      ")",
      [cutoff],
    );

    return count;
  }

  /// Permanently deletes all failed-delivery records that have been verified
  /// by the hub team. These records are no longer actionable by the courier.
  Future<int> purgeVerifiedRecords() async {
    final db = await _db;
    // Guard: do not purge if an unresolved sync operation exists for this barcode.
    return await db.rawDelete(
      "DELETE FROM local_deliveries "
      "WHERE rts_verification_status COLLATE NOCASE IN ('verified_with_pay', 'verified_no_pay') "
      "AND barcode NOT IN ("
      "  SELECT DISTINCT barcode FROM sync_operations "
      "  WHERE status IN ('pending', 'processing', 'failed', 'conflict')"
      ")",
    );
  }
}
