import 'package:flutter/foundation.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';

/// Fetches the courier's current delivery list from the server and seeds the
/// local SQLite database so the app has data to display while offline.
///
/// ## Sync Rules (highest priority first)
///
/// ### Rule 1 — Priority: Reconcile local pending items against the server FIRST
/// When online, every locally-pending barcode is checked against the server
/// immediately before the full sync. If the server's current pending list does
/// NOT contain a barcode, its individual detail is fetched (GET /deliveries/:barcode)
/// to determine whether it was updated (delivered/rts/osa) or removed entirely.
/// This ensures that manual web-app status changes are reflected without waiting
/// for the full status sweep.
///
/// ### Rule 2 — Never downgrade a courier's local delivery
/// If the courier has recorded a terminal status (delivered/rts/osa) locally,
/// a server-returning-pending response does NOT overwrite it. The courier's
/// own action is trusted until the server's terminal record wins.
///
/// ### Rule 3 — Accept server authority for terminal status changes
/// If the SERVER returns an item with a different terminal status than what is
/// stored locally (e.g., web admin changed rts → osa), the local record is
/// updated to match.
///
/// ### Rule 4 — Remove genuinely gone items
/// After a full sync, any locally-pending barcode not present in ANY server
/// status list is deleted. These are deliveries that were cancelled, removed,
/// or reassigned to another courier by a web admin.
///
/// This is a **best-effort** operation. Errors are silently swallowed.
class DeliveryBootstrapService {
  const DeliveryBootstrapService._();

  static const DeliveryBootstrapService instance = DeliveryBootstrapService._();

  static const List<String> _statuses = [
    'PENDING',
    'RTS',
    'OSA',
    'DELIVERED',
  ];

  // ── Public API ────────────────────────────────────────────────────────────

  /// Full sync with progress callbacks. Used by [InitialSyncScreen] to show
  /// live status messages during the first-time data pull.
  Future<void> syncFromApiWithProgress(
    ApiClient client, {
    void Function(String message)? onProgress,
  }) async {
    debugPrint('[SYNC] syncFromApiWithProgress — start');
    onProgress?.call('Reconciling local data...');
    await _priorityPendingReconciliation(client);

    final serverBarcodesPerStatus = <String, Set<String>>{};
    const statusLabels = {
      'PENDING': 'Fetching pending deliveries...',
      'RTS': 'Fetching RTS orders...',
      'OSA': 'Fetching OSA orders...',
      'DELIVERED': 'Fetching delivered orders...',
    };

    for (final status in _statuses) {
      onProgress?.call(statusLabels[status] ?? 'Syncing $status...');
      final barcodes = await _syncStatus(client, status);
      debugPrint('[SYNC] $status — fetched ${barcodes.length} barcodes');
      serverBarcodesPerStatus[status] = barcodes;
    }

    onProgress?.call('Cleaning up stale data...');
    try {
      final allServerBarcodes = <String>{
        for (final barcodes in serverBarcodesPerStatus.values) ...barcodes,
      };
      await LocalDeliveryDao.instance.removeStaleLocalPending(allServerBarcodes);
      debugPrint('[SYNC] cleanup done — total server barcodes: ${allServerBarcodes.length}');
    } catch (e) {
      debugPrint('[SYNC] cleanup error: $e');
    }
    debugPrint('[SYNC] syncFromApiWithProgress — complete');
  }

  /// Clears the local delivery table and re-fetches all deliveries from the
  /// server. Used for the "Reload from Server" action on the Sync screen.
  Future<void> clearAndSyncFromApi(ApiClient client) async {
    await LocalDeliveryDao.instance.deleteAll();
    await syncFromApi(client);
  }

  /// Wipes local data first, then runs a full sync with progress callbacks.
  /// Used by [InitialSyncScreen] to guarantee a clean slate on every first load.
  Future<void> clearAndSyncFromApiWithProgress(
    ApiClient client, {
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Clearing local data...');
    await LocalDeliveryDao.instance.deleteAll();
    await syncFromApiWithProgress(client, onProgress: onProgress);
  }

  /// Full sync: reconcile local pending items FIRST, then sweep all statuses.
  Future<void> syncFromApi(ApiClient client) async {
    debugPrint('[SYNC] syncFromApi — start');
    // ── Phase 0 (PRIORITY): Reconcile local pending vs server ────────────────
    await _priorityPendingReconciliation(client);

    // ── Phase 1: Full status sweep ────────────────────────────────────────────
    final serverBarcodesPerStatus = <String, Set<String>>{};
    for (final status in _statuses) {
      final barcodes = await _syncStatus(client, status);
      debugPrint('[SYNC] $status — fetched ${barcodes.length} barcodes');
      serverBarcodesPerStatus[status] = barcodes;
    }

    // ── Phase 2: Remove stale local pending items ─────────────────────────────
    try {
      final allServerBarcodes = <String>{
        for (final barcodes in serverBarcodesPerStatus.values) ...barcodes,
      };
      await LocalDeliveryDao.instance.removeStaleLocalPending(allServerBarcodes);
      debugPrint('[SYNC] cleanup done — total server barcodes: ${allServerBarcodes.length}');
    } catch (e) {
      debugPrint('[SYNC] cleanup error: $e');
    }
    debugPrint('[SYNC] syncFromApi — complete');
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// PRIORITY PHASE: Immediately reconcile all locally-pending barcodes
  /// against the server's current state. Runs before the full status sweep.
  ///
  /// Steps:
  /// 1. Fetch all local pending barcodes from SQLite.
  /// 2. Fetch the server's full current pending list (all pages).
  /// 3. For any local pending barcode NOT in the server's pending list:
  ///    a. Call `GET /deliveries/:barcode` to check the real server status.
  ///    b. If found with a terminal status → update local record accordingly.
  ///    c. If not found (404 / error) → leave for Phase 2 cleanup.
  Future<void> _priorityPendingReconciliation(ApiClient client) async {
    try {
      // Step 1: Get all locally-pending barcodes.
      final localPendingBarcodes =
          await LocalDeliveryDao.instance.getPendingBarcodes();
      debugPrint('[SYNC] priority reconciliation — local pending: ${localPendingBarcodes.length}');
      if (localPendingBarcodes.isEmpty) return;

      // Step 2: Fetch server's pending list (all pages).
      final serverPendingBarcodes = await _fetchAllBarcodesForStatus(
        client,
        'pending',
      );

      // Step 3: Find locally-pending items missing from server's pending list.
      final missingFromPending = localPendingBarcodes
          .where((b) => !serverPendingBarcodes.contains(b))
          .toList();

      debugPrint('[SYNC] server pending: ${serverPendingBarcodes.length}, missing from pending: ${missingFromPending.length}');
      if (missingFromPending.isEmpty) return;

      // For each missing barcode, fetch its individual detail from the server.
      // Use small concurrency batches to avoid hammering the API.
      const batchSize = 5;
      for (var i = 0; i < missingFromPending.length; i += batchSize) {
        final chunk = missingFromPending.skip(i).take(batchSize);
        await Future.wait(
          chunk.map((barcode) => _reconcileOneBarcode(client, barcode)),
        );
      }
    } catch (_) {
      // Priority reconciliation is best-effort.
    }
  }

  /// Fetches the server detail for a single [barcode] and updates the local
  /// record if the server has a different (terminal) status.
  Future<void> _reconcileOneBarcode(ApiClient client, String barcode) async {
    try {
      final result = await client.get<Map<String, dynamic>>(
        '/deliveries/$barcode',
        parser: parseApiMap,
      );

      if (result is! ApiSuccess<Map<String, dynamic>>) return;

      final data = result.data;
      // The detail endpoint wraps the item under 'data'.
      final item = data['data'];
      if (item is! Map<String, dynamic>) return;

      final serverStatus = item['delivery_status']?.toString() ?? '';
      if (serverStatus.isEmpty || serverStatus == 'pending') return;

      // Server has a non-pending status — update the local record.
      await LocalDeliveryDao.instance.insertAllFromApiItems(
        [item],
        serverStatus: serverStatus,
      );
    } catch (_) {
      // Per-barcode errors are silently ignored.
    }
  }

  /// Fetches all barcodes for [status] across all pages without upserting.
  /// Used purely to compare against local state during priority reconciliation.
  Future<Set<String>> _fetchAllBarcodesForStatus(
    ApiClient client,
    String status,
  ) async {
    final allBarcodes = <String>{};
    int page = 1;
    int lastPage = 1;

    do {
      try {
        final result = await client.get<Map<String, dynamic>>(
          '/deliveries',
          queryParameters: {'status': status, 'per_page': 100, 'page': page},
          parser: parseApiMap,
        );
        if (result is! ApiSuccess<Map<String, dynamic>>) break;

        final data = result.data;
        final rawList = data['data'];
        if (rawList is List) {
          for (final item in rawList) {
            if (item is! Map) continue;
            final b = (item['barcode_value']?.toString() ??
                    item['barcode']?.toString() ??
                    item['tracking_number']?.toString() ??
                    '')
                .trim();
            if (b.isNotEmpty) allBarcodes.add(b);
          }
        }

        final meta = data['pagination'] ?? data['meta'];
        if (meta is Map<String, dynamic>) {
          lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
        } else {
          break;
        }
        page++;
      } catch (_) {
        break;
      }
    } while (page <= lastPage);

    return allBarcodes;
  }

  /// Fetches all pages for [status], upserts them, and returns all barcodes.
  Future<Set<String>> _syncStatus(ApiClient client, String status) async {
    final allBarcodes = <String>{};
    int page = 1;
    int lastPage = 1;

    do {
      try {
        final result = await client.get<Map<String, dynamic>>(
          '/deliveries',
          queryParameters: {'status': status, 'per_page': 50, 'page': page},
          parser: parseApiMap,
        );

        if (result is! ApiSuccess<Map<String, dynamic>>) {
          debugPrint('[SYNC] _syncStatus($status) page=$page non-success: $result');
          break;
        }

        final data = result.data;
        final rawList = data['data'];
        final items = <Map<String, dynamic>>[];
        if (rawList is List) {
          for (final item in rawList) {
            if (item is Map<String, dynamic>) {
              items.add(item);
            } else if (item is Map) {
              items.add(Map<String, dynamic>.from(item));
            }
          }
        } else {
          debugPrint('[SYNC] _syncStatus($status) page=$page — data.data is not a List: ${rawList.runtimeType}');
          break;
        }

        debugPrint('[SYNC] _syncStatus($status) page=$page — ${items.length} items');

        if (items.isNotEmpty) {
          await LocalDeliveryDao.instance.insertAllFromApiItems(
            items,
            serverStatus: status,
          );
          for (final item in items) {
            final b = (item['barcode_value']?.toString() ??
                    item['barcode']?.toString() ??
                    item['tracking_number']?.toString() ??
                    '')
                .trim();
            if (b.isNotEmpty) allBarcodes.add(b);
          }
        }

        final meta = data['pagination'] ?? data['meta'];
        if (meta is Map<String, dynamic>) {
          lastPage = (meta['last_page'] as num?)?.toInt() ?? 1;
          debugPrint('[SYNC] _syncStatus($status) page=$page/$lastPage');
        } else {
          debugPrint('[SYNC] _syncStatus($status) — no pagination meta, stopping');
          break;
        }
        page++;
      } catch (e) {
        debugPrint('[SYNC] _syncStatus($status) page=$page EXCEPTION: $e');
        break;
      }
    } while (page <= lastPage);

    return allBarcodes;
  }
}
