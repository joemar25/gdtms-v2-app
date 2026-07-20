// DOCS: docs/development-standards.md
// DOCS: docs/core/sync.md — update that file when you edit this one.
// DOCS: docs/architecture/accuracy-and-scale.md

import 'package:flutter/foundation.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/bagsakan_dao.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/sync/sync_upsert_policy.dart';
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
/// to determine whether it was updated (delivered/failed-delivery/misrouted) or removed entirely.
/// This ensures that manual web-app status changes are reflected without waiting
/// for the full status sweep.
///
/// ### Rule 2 — Never downgrade a courier's local delivery
/// If the courier has recorded a terminal status (delivered/failed-delivery/misrouted) locally,
/// a server-returning-pending response does NOT overwrite it. The courier's
/// own action is trusted until the server's terminal record wins.
///
/// ### Rule 3 — Accept server authority for terminal status changes
/// If the SERVER returns an item with a different terminal status than what is
/// stored locally (e.g., web admin changed failed_delivery → misrouted), the local record is
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

  /// API status buckets fetched during a full sync.
  /// Derived from [DeliveryStatus] so the strings stay in sync with the enum.
  static final List<String> _statuses = [
    DeliveryStatus.pending.toApiString(), // 'FOR_DELIVERY' — new standard
    DeliveryStatus.failedDelivery.toApiString(), // 'FAILED_DELIVERY'
    DeliveryStatus.misrouted.toApiString(), // 'MISROUTED'
    DeliveryStatus.delivered.toApiString(), // 'DELIVERED'
  ];

  /// Page size for delivery list / delta sync (P2). Server paging is cheap;
  /// fewer RTTs dominate total sync time after the timeline index fix.
  static const int kSyncPerPage = 150;

  /// Max concurrent page fetches within one status (P1). Polite to API.
  static const int _kPageConcurrency = 3;

  int _asPositiveInt(dynamic value, {int fallback = 1}) {
    if (value is num) {
      final v = value.toInt();
      return v > 0 ? v : fallback;
    }
    if (value is String) {
      final v = int.tryParse(value.trim());
      if (v != null && v > 0) return v;
    }
    return fallback;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Full sync with progress callbacks. Used by [InitialSyncScreen] to show
  /// live status messages during the first-time data pull.
  Future<void> syncFromApiWithProgress(
    ApiClient client, {
    void Function(String message)? onProgress,
  }) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final updatedSince = await AuthStorage().getLastSyncTime();

    debugPrint(
      '[SYNC] syncFromApiWithProgress — start (updatedSince: $updatedSince)',
    );
    onProgress?.call('Reconciling local data...');
    await _priorityPendingReconciliation(client);

    final serverBarcodesPerStatus = <String, Set<String>>{};

    if (updatedSince != null && updatedSince > 0) {
      onProgress?.call('Fetching updates since last sync...');
      final deltaBarcodes = await _syncDelta(client, updatedSince);
      debugPrint('[SYNC] DELTA — fetched ${deltaBarcodes.length} barcodes');
      // For delta sync, we don't have separate status sets, so we just collect all.
      // Phase 2 cleanup will only remove items that were PENDING but are now gone.
      serverBarcodesPerStatus['DELTA'] = deltaBarcodes;
    } else {
      // P1: parallel status sweeps (same requests as sequential; Phase 2 waits).
      onProgress?.call('Fetching deliveries (all statuses)...');
      final sweep = await Future.wait(
        _statuses.map((status) async {
          final barcodes = await _syncStatus(client, status);
          debugPrint('[SYNC] $status — fetched ${barcodes.length} barcodes');
          return MapEntry(status, barcodes);
        }),
      );
      for (final e in sweep) {
        serverBarcodesPerStatus[e.key] = e.value;
      }
    }

    // ── Phase 1b: Sync Bagsakan Groups (Authoritative) ───────────────────────
    onProgress?.call('Syncing bagsakan groups...');
    // Returns null when the network was unreachable — skip stale purge in that
    // case to avoid deleting groups that are merely temporarily inaccessible.
    final serverGroupIds = await _syncBagsakanGroupsFromUnifiedSync(client);
    if (serverGroupIds != null) {
      await BagsakanDao.instance.removeStaleGroups(serverGroupIds);
    }

    onProgress?.call('Cleaning up stale data...');
    try {
      final allServerBarcodes = <String>{
        for (final barcodes in serverBarcodesPerStatus.values) ...barcodes,
      };

      // IMPORTANT: Step 2 cleanup is only safe if we performed a FULL sweep.
      // If this was a DELTA sync, we only know about UPDATED items.
      // We cannot assume items missing from a delta response are gone.
      if (updatedSince == null || updatedSince <= 0) {
        await LocalDeliveryDao.instance.removeStaleLocalPending(
          allServerBarcodes,
        );
        debugPrint(
          '[SYNC] cleanup done — total server barcodes: ${allServerBarcodes.length}',
        );
      } else {
        debugPrint(
          '[SYNC] delta sync — skipping Phase 2 cleanup (Rule 4 inapplicable)',
        );
      }
    } catch (e) {
      debugPrint('[SYNC] cleanup error: $e');
    }

    // ── Phase 3: Immediate purge of verified records ─────────────────────────
    onProgress?.call('Finalizing cleanup...');
    try {
      final purgedCount = await LocalDeliveryDao.instance
          .purgeVerifiedRecords();
      if (purgedCount > 0) {
        debugPrint('[SYNC] purged $purgedCount verified records from local DB');
      }
    } catch (e) {
      debugPrint('[SYNC] verified purge error: $e');
    }

    await AuthStorage().setLastSyncTime(startTime);
    debugPrint('[SYNC] syncFromApiWithProgress — complete');
  }

  /// Clears the local delivery table and re-fetches all deliveries from the
  /// server. Used for the "Reload from Server" action on the Sync screen.
  Future<void> clearAndSyncFromApi(ApiClient client) async {
    await AuthStorage().setLastSyncTime(0); // Force full sync
    await LocalDeliveryDao.instance.deleteAll();
    await BagsakanDao.instance.deleteAllGroups();
    await syncFromApi(client);
  }

  /// Wipes local data first, then runs a full sync with progress callbacks.
  /// Used by [InitialSyncScreen] to guarantee a clean slate on every first load.
  Future<void> clearAndSyncFromApiWithProgress(
    ApiClient client, {
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('Clearing local data...');
    await AuthStorage().setLastSyncTime(0); // Force full sync
    await LocalDeliveryDao.instance.deleteAll();
    await BagsakanDao.instance.deleteAllGroups();
    await syncFromApiWithProgress(client, onProgress: onProgress);
  }

  /// Full sync: reconcile local pending items FIRST, then sweep statuses (or delta).
  Future<void> syncFromApi(ApiClient client) async {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    final updatedSince = await AuthStorage().getLastSyncTime();

    debugPrint('[SYNC] syncFromApi — start (updatedSince: $updatedSince)');
    // ── Phase 0 (PRIORITY): Reconcile local pending vs server ────────────────
    await _priorityPendingReconciliation(client);

    // ── Phase 1: Status sweep or Delta sync ──────────────────────────────────
    final serverBarcodesPerStatus = <String, Set<String>>{};

    if (updatedSince != null && updatedSince > 0) {
      final deltaBarcodes = await _syncDelta(client, updatedSince);
      debugPrint('[SYNC] DELTA — fetched ${deltaBarcodes.length} barcodes');
      serverBarcodesPerStatus['DELTA'] = deltaBarcodes;
    } else {
      // P1: parallel status sweeps — Phase 2 cleanup still waits for all.
      final sweep = await Future.wait(
        _statuses.map((status) async {
          final barcodes = await _syncStatus(client, status);
          debugPrint('[SYNC] $status — fetched ${barcodes.length} barcodes');
          return MapEntry(status, barcodes);
        }),
      );
      for (final e in sweep) {
        serverBarcodesPerStatus[e.key] = e.value;
      }
    }

    // ── Phase 1b: Sync Bagsakan Groups (Authoritative) ───────────────────────
    // Returns null when the network was unreachable — skip stale purge in that
    // case to avoid deleting groups that are merely temporarily inaccessible.
    final serverGroupIds = await _syncBagsakanGroupsFromUnifiedSync(client);
    if (serverGroupIds != null) {
      await BagsakanDao.instance.removeStaleGroups(serverGroupIds);
    }

    // ── Phase 2: Remove stale local pending items ─────────────────────────────
    // Skip if delta sync (see rule 4 in syncFromApiWithProgress).
    if (updatedSince == null || updatedSince <= 0) {
      try {
        final allServerBarcodes = <String>{
          for (final barcodes in serverBarcodesPerStatus.values) ...barcodes,
        };
        await LocalDeliveryDao.instance.removeStaleLocalPending(
          allServerBarcodes,
        );
        debugPrint(
          '[SYNC] cleanup done — total server barcodes: ${allServerBarcodes.length}',
        );
      } catch (e) {
        debugPrint('[SYNC] cleanup error: $e');
      }
    }

    // ── Phase 3: Immediate purge of verified records ─────────────────────────
    // Logic: verified records are terminal and non-actionable; they must not
    // exist in the local database.
    try {
      final purgedCount = await LocalDeliveryDao.instance
          .purgeVerifiedRecords();
      if (purgedCount > 0) {
        debugPrint('[SYNC] purged $purgedCount verified records from local DB');
      }
    } catch (e) {
      debugPrint('[SYNC] verified purge error: $e');
    }

    await AuthStorage().setLastSyncTime(startTime);
    debugPrint('[SYNC] syncFromApi — complete');
  }

  /// Fetches only FOR_DELIVERY items from the server and seeds local SQLite.
  /// Called immediately after accepting a dispatch so the delivery list is
  /// populated without running the full multi-status sync.
  Future<void> seedForDelivery(ApiClient client) async {
    await _syncStatus(client, DeliveryStatus.pending.toApiString());
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
      final localPendingBarcodes = await LocalDeliveryDao.instance
          .getPendingBarcodes();
      debugPrint(
        '[SYNC] priority reconciliation — local pending: ${localPendingBarcodes.length}',
      );
      if (localPendingBarcodes.isEmpty) return;

      // Step 2: Use the new v3.3 batch verification endpoint.
      final result = await client.post<Map<String, dynamic>>(
        '/deliveries/verify-status',
        data: {'barcodes': localPendingBarcodes.toList()},
        parser: parseApiMap,
      );

      if (result is! ApiSuccess<Map<String, dynamic>>) {
        debugPrint('[SYNC] batch verification failed: $result');
        return;
      }

      final data = result.data['data'];
      if (data is! List) return;

      final serverUpdates = <Map<String, dynamic>>[];
      for (final update in data) {
        if (update is! Map<String, dynamic>) continue;

        final barcode = _str(update, 'barcode') ?? '';
        final serverStatus = _str(update, 'status') ?? '';

        if (barcode.isEmpty || serverStatus.isEmpty) continue;

        // If the status is no longer PENDING (FOR_DELIVERY), it needs reconciliation.
        if (DeliveryStatus.fromString(serverStatus) != DeliveryStatus.pending) {
          serverUpdates.add({
            'barcode': barcode,
            'delivery_status': serverStatus,
            'updated_at': _str(update, 'updated_at'),
          });
        }
      }

      if (serverUpdates.isNotEmpty) {
        debugPrint(
          '[SYNC] batch verification found ${serverUpdates.length} updates',
        );
        // insertAllFromApiItems handles terminal status protection and timestamps.
        await LocalDeliveryDao.instance.insertAllFromApiItems(serverUpdates);
      }
    } catch (e) {
      debugPrint('[SYNC] priority reconciliation error: $e');
    }
  }

  static String? _str(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// One page of GET /deliveries (status or delta query).
  Future<({List<Map<String, dynamic>> items, int lastPage})?>
  _fetchDeliveriesPage(
    ApiClient client, {
    required Map<String, dynamic> query,
    required String logLabel,
  }) async {
    try {
      final result = await client.get<Map<String, dynamic>>(
        '/deliveries',
        queryParameters: query,
        parser: parseApiMap,
      );

      if (result is! ApiSuccess<Map<String, dynamic>>) {
        debugPrint('[SYNC] $logLabel non-success: $result');
        return null;
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
        debugPrint(
          '[SYNC] $logLabel — data.data is not a List: ${rawList.runtimeType}',
        );
        return null;
      }

      var lastPage = 1;
      final meta = data['pagination'] ?? data['meta'];
      if (meta is Map<String, dynamic>) {
        lastPage = _asPositiveInt(meta['last_page']);
      } else {
        debugPrint('[SYNC] $logLabel — no pagination meta');
      }

      debugPrint(
        '[SYNC] $logLabel — ${items.length} items (last_page=$lastPage)',
      );
      return (items: items, lastPage: lastPage);
    } catch (e) {
      debugPrint('[SYNC] $logLabel EXCEPTION: $e');
      return null;
    }
  }

  Future<void> _upsertPageItems(
    List<Map<String, dynamic>> items, {
    String? serverStatus,
    required Set<String> allBarcodes,
  }) async {
    if (items.isEmpty) return;
    if (serverStatus != null) {
      await LocalDeliveryDao.instance.insertAllFromApiItems(
        items,
        serverStatus: serverStatus,
      );
    } else {
      await LocalDeliveryDao.instance.insertAllFromApiItems(items);
    }
    for (final item in items) {
      final b = (item['barcode']?.toString() ?? '').trim();
      if (b.isNotEmpty) allBarcodes.add(b);
    }
  }

  /// Fetches all pages for [status], upserts them, and returns all barcodes.
  ///
  /// P1: page 1 first (learn last_page), then pages 2..N with concurrency cap.
  /// P2: [kSyncPerPage] items per request.
  Future<Set<String>> _syncStatus(ApiClient client, String status) async {
    final allBarcodes = <String>{};
    final first = await _fetchDeliveriesPage(
      client,
      query: {'status': status, 'per_page': kSyncPerPage, 'page': 1},
      logLabel: '_syncStatus($status) page=1',
    );
    if (first == null) return allBarcodes;

    await _upsertPageItems(
      first.items,
      serverStatus: status,
      allBarcodes: allBarcodes,
    );

    final lastPage = first.lastPage;
    if (lastPage <= 1) return allBarcodes;

    final remaining = DeliverySyncPaging.remainingPages(lastPage);
    for (final chunk in DeliverySyncPaging.chunkPages(
      remaining,
      _kPageConcurrency,
    )) {
      final pages = await Future.wait(
        chunk.map(
          (page) => _fetchDeliveriesPage(
            client,
            query: {
              'status': status,
              'per_page': kSyncPerPage,
              'page': page,
            },
            logLabel: '_syncStatus($status) page=$page',
          ),
        ),
      );
      for (final pageResult in pages) {
        if (pageResult == null) continue;
        await _upsertPageItems(
          pageResult.items,
          serverStatus: status,
          allBarcodes: allBarcodes,
        );
      }
    }

    return allBarcodes;
  }

  /// Fetches delta updates using updated_since and upserts them.
  /// P1/P2: same page concurrency + [kSyncPerPage] as status sweep.
  Future<Set<String>> _syncDelta(ApiClient client, int updatedSince) async {
    final allBarcodes = <String>{};
    final sinceIso = DateTime.fromMillisecondsSinceEpoch(
      updatedSince,
    ).toUtc().toIso8601String();

    final first = await _fetchDeliveriesPage(
      client,
      query: {
        'updated_since': sinceIso,
        'per_page': kSyncPerPage,
        'page': 1,
      },
      logLabel: '_syncDelta page=1',
    );
    if (first == null) return allBarcodes;

    await _upsertPageItems(first.items, allBarcodes: allBarcodes);

    final lastPage = first.lastPage;
    if (lastPage <= 1) return allBarcodes;

    final remaining = DeliverySyncPaging.remainingPages(lastPage);
    for (final chunk in DeliverySyncPaging.chunkPages(
      remaining,
      _kPageConcurrency,
    )) {
      final pages = await Future.wait(
        chunk.map(
          (page) => _fetchDeliveriesPage(
            client,
            query: {
              'updated_since': sinceIso,
              'per_page': kSyncPerPage,
              'page': page,
            },
            logLabel: '_syncDelta page=$page',
          ),
        ),
      );
      for (final pageResult in pages) {
        if (pageResult == null) continue;
        await _upsertPageItems(pageResult.items, allBarcodes: allBarcodes);
      }
    }

    return allBarcodes;
  }

  /// Fetches bagsakan groups from the unified `/sync` stream and upserts them
  /// locally. Falls back to legacy `GET /bagsakan/groups` when unavailable.
  /// Returns null when both fetches fail (network unreachable) so callers
  /// can skip stale-group purge rather than wiping all locally-synced groups.
  Future<Set<int>?> _syncBagsakanGroupsFromUnifiedSync(ApiClient client) async {
    final groupsById = <Object, Map<String, dynamic>>{};
    int page = 1;
    int lastPage = 1;

    try {
      do {
        final query = <String, dynamic>{'page': page, 'per_page': 100};
        // authoritative group sync ignores delta updatedSince flags.

        final result = await client.get<Map<String, dynamic>>(
          '/sync',
          queryParameters: query,
          parser: parseApiMap,
        );

        if (result is! ApiSuccess<Map<String, dynamic>>) {
          debugPrint('[SYNC] /sync groups fetch failed on page=$page: $result');
          break;
        }

        final rawGroups = result.data['bagsakan_groups'];
        if (rawGroups is List) {
          for (final item in rawGroups) {
            final map = item is Map<String, dynamic>
                ? item
                : (item is Map ? Map<String, dynamic>.from(item) : null);
            if (map == null) continue;
            final id = map['id'];
            if (id != null) groupsById[id] = map;
          }
        }

        final meta = result.data['pagination'] ?? result.data['meta'];
        if (meta is Map<String, dynamic>) {
          lastPage = _asPositiveInt(meta['last_page']);
        } else {
          lastPage = page;
        }
        page++;
      } while (page <= lastPage);

      if (groupsById.isNotEmpty) {
        final groups = groupsById.values.toList(growable: false);
        debugPrint('[SYNC] fetched ${groups.length} bagsakan groups via /sync');
        final enriched = await _enrichGroupsWithBarcodes(client, groups);
        await BagsakanDao.instance.upsertGroupsFromSync(enriched);
        return groupsById.keys.map((k) => int.parse(k.toString())).toSet();
      }

      // Fallback for environments that have not yet exposed groups in /sync.
      return await _syncBagsakanGroupsLegacy(client);
    } catch (e) {
      debugPrint('[SYNC] _syncBagsakanGroupsFromUnifiedSync exception: $e');
      return await _syncBagsakanGroupsLegacy(client);
    }
  }

  /// Legacy groups fetch path, kept as fallback safety net.
  /// Returns null when the server is unreachable so callers skip stale purge.
  /// Returns an empty set when the server responds but the user has no groups.
  Future<Set<int>?> _syncBagsakanGroupsLegacy(ApiClient client) async {
    try {
      final result = await client.get<Map<String, dynamic>>(
        '/bagsakan/groups',
        parser: parseApiMap,
      );

      if (result is! ApiSuccess<Map<String, dynamic>>) {
        debugPrint('[SYNC] _syncBagsakanGroupsLegacy failed: $result');
        return null;
      }

      final rawData = result.data['data'];
      final serverIds = <int>{};
      final List<Map<String, dynamic>> groups = [];

      if (rawData is List) {
        for (final item in rawData) {
          if (item is Map<String, dynamic>) {
            groups.add(item);
          } else if (item is Map) {
            groups.add(Map<String, dynamic>.from(item));
          }
        }
      }

      if (groups.isNotEmpty) {
        debugPrint('[SYNC] fetched ${groups.length} bagsakan groups (legacy)');
        final enriched = await _enrichGroupsWithBarcodes(client, groups);
        await BagsakanDao.instance.upsertGroupsFromSync(enriched);
        for (final g in enriched) {
          final id = g['id'];
          if (id is int) serverIds.add(id);
          if (id is String) {
            final parsed = int.tryParse(id);
            if (parsed != null) serverIds.add(parsed);
          }
        }
      }
      return serverIds;
    } catch (e) {
      debugPrint('[SYNC] _syncBagsakanGroupsLegacy exception: $e');
      return null;
    }
  }

  /// Enriches a list of group metadata maps with a `barcodes` field by
  /// calling GET /bagsakan/groups/{id} for each non-archived group.
  ///
  /// The list endpoints (/sync bagsakan_groups, /bagsakan/groups) return only
  /// metadata (id, name, status, item_count …). The detail endpoint is the
  /// only source that returns the `deliveries` array with individual barcodes,
  /// which is what upsertGroupsFromSync needs to reconcile bagsakan_id on
  /// local_deliveries rows.
  ///
  /// Archived groups are passed through as-is — upsertGroupsFromSync unassigns
  /// their items without needing a barcode list.
  Future<List<Map<String, dynamic>>> _enrichGroupsWithBarcodes(
    ApiClient client,
    List<Map<String, dynamic>> groups,
  ) async {
    final enriched = <Map<String, dynamic>>[];
    for (final group in groups) {
      final id = group['id'];
      if (id == null) {
        enriched.add(group);
        continue;
      }

      final isArchived = group['is_archived'];
      if (isArchived == true || isArchived == 1) {
        enriched.add(group);
        continue;
      }

      try {
        final result = await client.get<Map<String, dynamic>>(
          '/bagsakan/groups/$id',
          parser: parseApiMap,
        );

        if (result is ApiSuccess<Map<String, dynamic>>) {
          final detail = result.data['data'];
          if (detail is Map<String, dynamic>) {
            final deliveries = detail['deliveries'];
            final barcodes = deliveries is List
                ? deliveries
                      .whereType<Map>()
                      .map((e) => e['barcode']?.toString().trim() ?? '')
                      .where((b) => b.isNotEmpty)
                      .toList()
                : <String>[];

            // Fetch and insert full delivery rows for each barcode.
            // The server hard-gates bagsakan-assigned deliveries out of
            // GET /deliveries?status=FOR_DELIVERY (WHERE bagsakan_id IS NULL),
            // so these rows never land in local_deliveries via the standard
            // _syncStatus sweep. We must seed them here so that the subsequent
            // upsertGroupsFromSync UPDATE finds rows to stamp with bagsakan_id.
            await _fetchAndInsertGroupDeliveries(client, barcodes, id);

            enriched.add({...group, 'barcodes': barcodes});
            debugPrint(
              '[SYNC] group $id enriched with ${barcodes.length} barcodes',
            );
            continue;
          }
        }
        debugPrint(
          '[SYNC] group $id: detail fetch non-success — using metadata only',
        );
      } catch (e) {
        debugPrint('[SYNC] group $id: detail fetch error: $e');
      }

      enriched.add(group);
    }
    return enriched;
  }

  /// Fetches full delivery data for each [barcode] via GET /deliveries/{barcode}
  /// and upserts the rows into local_deliveries.
  ///
  /// The server excludes bagsakan-assigned deliveries from the standard delivery
  /// list (hard gate: `WHERE deliveries.bagsakan_id IS NULL`). This method
  /// bridges that gap so upsertGroupsFromSync can find existing rows to update.
  Future<void> _fetchAndInsertGroupDeliveries(
    ApiClient client,
    List<String> barcodes,
    dynamic groupId,
  ) async {
    if (barcodes.isEmpty) return;

    final deliveryItems = <Map<String, dynamic>>[];

    for (final barcode in barcodes) {
      try {
        final result = await client.get<Map<String, dynamic>>(
          '/deliveries/$barcode',
          parser: parseApiMap,
        );

        if (result is ApiSuccess<Map<String, dynamic>>) {
          final data = result.data['data'];
          if (data is Map<String, dynamic>) {
            deliveryItems.add(data);
            debugPrint('[SYNC] group $groupId: fetched delivery $barcode');
          } else {
            debugPrint(
              '[SYNC] group $groupId: delivery $barcode — unexpected data shape',
            );
          }
        } else {
          debugPrint(
            '[SYNC] group $groupId: delivery $barcode fetch non-success: $result',
          );
        }
      } catch (e) {
        debugPrint('[SYNC] group $groupId: delivery $barcode fetch error: $e');
      }
    }

    if (deliveryItems.isNotEmpty) {
      await LocalDeliveryDao.instance.insertAllFromApiItems(
        deliveryItems,
        serverStatus: 'FOR_DELIVERY',
      );
      debugPrint(
        '[SYNC] group $groupId: seeded ${deliveryItems.length} group deliveries into local_deliveries',
      );
    }
  }
}
