import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retry/retry.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/services/error_log_service.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class SyncState {
  const SyncState({
    required this.isSyncing,
    this.currentBarcode,
    required this.processed,
    required this.total,
    required this.entries,
    this.lastMessage,
  });

  const SyncState.initial()
    : isSyncing = false,
      currentBarcode = null,
      processed = 0,
      total = 0,
      entries = const [],
      lastMessage = null;

  final bool isSyncing;

  /// Barcode of the delivery currently being pushed to the server.
  final String? currentBarcode;

  final int processed;
  final int total;

  /// All queue entries — used to drive the Sync screen list.
  final List<SyncOperation> entries;

  /// Human-readable status message shown in the Sync screen header.
  final String? lastMessage;

  SyncState copyWith({
    bool? isSyncing,
    Object? currentBarcode = _sentinel,
    int? processed,
    int? total,
    List<SyncOperation>? entries,
    Object? lastMessage = _sentinel,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      currentBarcode: currentBarcode == _sentinel
          ? this.currentBarcode
          : currentBarcode as String?,
      processed: processed ?? this.processed,
      total: total ?? this.total,
      entries: entries ?? this.entries,
      lastMessage: lastMessage == _sentinel
          ? this.lastMessage
          : lastMessage as String?,
    );
  }

  static const _sentinel = Object();
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SyncManagerNotifier extends StateNotifier<SyncState> {
  SyncManagerNotifier(this._ref) : super(const SyncState.initial());

  final Ref _ref;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Loads all queue entries from SQLite and refreshes [state.entries].
  /// Call this when opening the Sync screen.
  Future<void> loadEntries() async {
    final courier = _ref.read(authProvider).courier ?? {};
    final courierId = courier['id']?.toString() ?? '';
    final entries = await SyncOperationsDao.instance.getAll(courierId);
    if (mounted) state = state.copyWith(entries: entries);
  }

  /// Processes every [pending] queue entry sequentially.
  ///
  /// - Skips silently if already [isSyncing].
  /// - Updates [state] in real time so the UI stays reactive.
  /// - Runs [CleanupService] when all entries have been processed.
  Future<void> processQueue() async {
    if (state.isSyncing) return;

    final courier = _ref.read(authProvider).courier ?? {};
    final courierId = courier['id']?.toString() ?? '';
    final pending = await SyncOperationsDao.instance.getPending(courierId);
    if (pending.isEmpty) {
      await loadEntries();
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      processed: 0,
      total: pending.length,
      lastMessage: 'Starting synchronization…',
    );

    int successCount = 0;

    for (final entry in pending) {
      if (!mounted) break;

      state = state.copyWith(
        currentBarcode: entry.barcode,
        lastMessage: 'Updating delivery ${entry.barcode} to server…',
      );

      final attemptAt = DateTime.now().millisecondsSinceEpoch;
      await SyncOperationsDao.instance.updateStatus(entry.id, 'processing', lastAttemptAt: attemptAt);

      try {
        final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;

        // ── Upload any pending media (stored offline as local files) ────────────
        if (entry.mediaPathsJson != null && entry.mediaPathsJson!.isNotEmpty) {
          final pendingMedia = jsonDecode(entry.mediaPathsJson!) as Map<String, dynamic>;
          if (pendingMedia.isNotEmpty) {
            state = state.copyWith(
              lastMessage:
                  'Uploading media for ${entry.barcode} (${pendingMedia.length} file${pendingMedia.length == 1 ? '' : 's'})…',
            );
            final uploadedImages = <Map<String, dynamic>>[];
            final api = _ref.read(apiClientProvider);
            final uploadPath = '/deliveries/${entry.barcode}/media';

            debugPrint('[SYNC] media queue for ${entry.barcode}: ${pendingMedia.keys.join(', ')}');
            for (final kv in pendingMedia.entries) {
              final uploadType = kv.key; // e.g., 'pod', 'selfie', 'recipient_signature'
              final filePath = kv.value.toString();

              final file = File(filePath);
              if (!await file.exists()) {
                debugPrint('[SYNC] media file missing for $uploadType — skipping: $filePath');
                await ErrorLogService.warning(
                  context: 'sync',
                  message: 'Media file missing for ${entry.barcode} ($uploadType)',
                  detail: 'Path not found: $filePath',
                  barcode: entry.barcode,
                );
                continue;
              }

              final bytes = await file.readAsBytes();
              debugPrint('[SYNC] uploading $uploadType (${bytes.length}b) for ${entry.barcode}');
              final ext = filePath.endsWith('.png') ? 'png' : 'jpg';
              final filename = '$uploadType.$ext';

              final result = await api.uploadMedia<Map<String, dynamic>>(
                uploadPath,
                bytes: bytes,
                filename: filename,
                type: uploadType,
                parser: (d) {
                  if (d is Map<String, dynamic>) return d;
                  if (d is Map) return d.map((k, v) => MapEntry(k.toString(), v));
                  return <String, dynamic>{};
                },
              );

              if (result is ApiSuccess<Map<String, dynamic>>) {
                final inner = result.data['data'];
                final url = (inner is Map
                        ? inner['url'] ?? inner['signed_url'] ?? inner['file'] ?? inner['path']
                        : result.data['url'] ?? result.data['signed_url'])?.toString();

                if (url != null && url.isNotEmpty) {
                  debugPrint('[SYNC] $uploadType uploaded → $url');
                  if (uploadType == 'recipient_signature') {
                    payload['recipient_signature'] = url;
                  } else {
                    uploadedImages.add({
                      'file': url,
                      'type': uploadType,
                      'captured_at': DateTime.now().toUtc().toIso8601String(),
                    });
                  }
                } else {
                  debugPrint('[SYNC] $uploadType upload succeeded but URL was null/empty — dropped');
                  await ErrorLogService.warning(
                    context: 'sync',
                    message: 'Upload URL missing for ${entry.barcode} ($uploadType)',
                    detail: 'ApiSuccess returned null/empty URL. data=${result.data}',
                    barcode: entry.barcode,
                  );
                }
              } else {
                debugPrint('[SYNC] $uploadType upload failed: $result');
                await ErrorLogService.warning(
                  context: 'sync',
                  message: 'Upload failed for ${entry.barcode} ($uploadType)',
                  detail: result.toString(),
                  barcode: entry.barcode,
                );
              }
            }
            debugPrint('[SYNC] uploadedImages after loop: ${uploadedImages.map((e) => e['type']).join(', ')}');

            if (uploadedImages.isNotEmpty) {
              final existing = payload['delivery_images'];
              final merged = <Map<String, dynamic>>[
                if (existing is List) ...existing.whereType<Map<String, dynamic>>(),
                ...uploadedImages,
              ];
              payload['delivery_images'] = merged;
            }

            final hasSignature = payload.containsKey('recipient_signature');
            if (pendingMedia.isNotEmpty && uploadedImages.isEmpty && !hasSignature) {
              final newRetryCount = entry.retryCount + 1;
              const mediaError = 'Media upload failed — no proof photos could be uploaded.';
              await SyncOperationsDao.instance.updateStatus(
                entry.id,
                'failed',
                lastError: mediaError,
                retryCount: newRetryCount,
              );
              await ErrorLogService.warning(
                context: 'sync',
                message: 'Media upload failed for ${entry.barcode}',
                detail: mediaError,
                barcode: entry.barcode,
              );
              state = state.copyWith(
                processed: state.processed + 1,
                lastMessage: 'Media upload failed for ${entry.barcode}. Will retry.',
              );
              continue;
            }
          }
        }

        final result = await retry<ApiResult<Map<String, dynamic>>>(
          () async {
            final res = await _ref
                .read(apiClientProvider)
                .patch<Map<String, dynamic>>(
                  '/deliveries/${entry.barcode}',
                  data: payload,
                  extraHeaders: {'X-Request-ID': entry.id}, // Use op UUID for idempotency
                  parser: parseApiMap,
                );
            if (res is ApiNetworkError || res is ApiServerError || res is ApiRateLimited) {
              throw Exception('Transient error during PATCH: ${_errorMessage(res)}');
            }
            return res;
          },
          maxAttempts: 3,
          delayFactor: const Duration(milliseconds: 500),
        );

        if (!mounted) break;

        if (result is ApiSuccess<Map<String, dynamic>>) {
          await SyncOperationsDao.instance.updateStatus(entry.id, 'synced');
          final deliveryData = result.data['data'];
          if (deliveryData is Map<String, dynamic>) {
            await LocalDeliveryDao.instance.updateFromJson(
              entry.barcode,
              deliveryData,
            );
          } else {
            // Payload stores UPPERCASE status (server format); normalise to
            // lowercase before writing to local DB (internal app format).
            final status = payload['delivery_status']?.toString().toUpperCase();
            if (status != null) {
              await LocalDeliveryDao.instance.updateStatus(
                entry.barcode,
                status,
              );
            }
          }
          successCount++;
          state = state.copyWith(
            processed: state.processed + 1,
            lastMessage: 'Delivery ${entry.barcode} successfully synced.',
          );
        } else if (result is ApiConflict<Map<String, dynamic>> || 
                   result is ApiBadRequest<Map<String, dynamic>> || 
                   result is ApiValidationError<Map<String, dynamic>>) {
          // Terminal conflicts/errors from server -> abandon retry, mark as conflict or resolve automatically
          final errorMsg = _errorMessage(result);
          
          // Auto-resolve cases where the server already reflects what the courier wanted:
          //
          // Case 1 — Immutable DELIVERED: server says item is already DELIVERED and
          //   cannot be changed. If the courier intended DELIVERED, end-state matches.
          final isDeliveredImmutable = errorMsg.toLowerCase().contains('delivered') &&
                                       errorMsg.toLowerCase().contains('immutable');
          final wasIntendingToDeliver =
              payload['delivery_status']?.toString().toUpperCase() == 'DELIVERED';

          // Case 2 — Same-status transition: server rejected because status is
          //   already what the courier wanted (e.g. "Invalid status transition
          //   from 'RTS' to 'RTS'"). Safe to mark as synced.
          final targetStatus =
              payload['delivery_status']?.toString().toLowerCase() ?? '';
          final isSameStatusTransition =
              targetStatus.isNotEmpty &&
              errorMsg.toLowerCase().contains('invalid status transition') &&
              errorMsg.toLowerCase().contains("to '$targetStatus'");

          if ((isDeliveredImmutable && wasIntendingToDeliver) || isSameStatusTransition) {
            await SyncOperationsDao.instance.updateStatus(entry.id, 'synced', lastError: 'Resolved: $errorMsg');
            successCount++;
            state = state.copyWith(
              processed: state.processed + 1,
              lastMessage: 'Delivery ${entry.barcode} already updated on server.',
            );
          } else {
            await SyncOperationsDao.instance.updateStatus(entry.id, 'conflict', lastError: errorMsg);
            await ErrorLogService.warning(
              context: 'sync',
              message: 'Conflict on ${entry.barcode}',
              detail: errorMsg,
              barcode: entry.barcode,
            );
            state = state.copyWith(
              processed: state.processed + 1,
              lastMessage: 'Conflict on ${entry.barcode}: $errorMsg',
            );
          }
        } else {
          final errorMsg = _errorMessage(result);
          final newRetryCount = entry.retryCount + 1;
          await SyncOperationsDao.instance.updateStatus(entry.id, 'failed', lastError: errorMsg, retryCount: newRetryCount);
          await ErrorLogService.log(
            context: 'sync',
            message: 'Failed to sync ${entry.barcode}',
            detail: errorMsg,
            barcode: entry.barcode,
          );
          state = state.copyWith(
            processed: state.processed + 1,
            lastMessage: 'Failed to sync ${entry.barcode}: $errorMsg',
          );
        }
      } catch (e) {
        final newRetryCount = entry.retryCount + 1;
        await SyncOperationsDao.instance.updateStatus(entry.id, 'failed', lastError: e.toString(), retryCount: newRetryCount);
        await ErrorLogService.log(
          context: 'sync',
          message: 'Exception syncing ${entry.barcode}',
          detail: e.toString(),
          barcode: entry.barcode,
        );
        state = state.copyWith(
          processed: state.processed + 1,
          lastMessage: 'Error syncing ${entry.barcode}.',
        );
      }
    }

    if (mounted && successCount > 0) {
      _ref.read(deliveryRefreshProvider.notifier).state++;
    }

    // Run cleanup after every sync cycle (non-blocking concern).
    // Import is deferred at runtime to avoid circular reference at parse time.
    _runCleanupSilently();

    final allEntries = await SyncOperationsDao.instance.getAll(courierId);
    if (mounted) {
      state = state.copyWith(
        isSyncing: false,
        currentBarcode: null,
        entries: allEntries,
        lastMessage: successCount > 0
            ? '$successCount update${successCount == 1 ? '' : 's'} synced successfully.'
            : pending.isNotEmpty
            ? 'Sync complete. Some updates may have failed.'
            : 'Nothing to sync.',
      );
    }
  }

  /// Waits until [isSyncing] is false, polling at short intervals.
  ///
  /// Call this in [_runFullSync] after [processQueue] returns to ensure any
  /// concurrent fire-and-forget [processQueue] invocation has fully drained
  /// before starting `syncFromApi`. Without this guard the two operations can
  /// overlap: `syncFromApi` overwrites the local DB while `processQueue` is
  /// still mid-flight, causing the PATCH to arrive after the server has
  /// already applied the status — producing spurious 400 errors.
  Future<void> waitUntilIdle() async {
    while (state.isSyncing) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  /// Resets a single [failed] entry back to [pending] and immediately
  /// processes the queue. Intended for manual retry from the Sync screen.
  Future<void> retrySingle(String id) async {
    if (state.isSyncing) return;
    await SyncOperationsDao.instance.resetToPending(id);
    await processQueue();
  }

  /// Clears all failed entries and refreshes the list.
  Future<void> clearFailed() async {
    final auth = _ref.read(authProvider);
    if (auth.courier == null) return;
    await SyncOperationsDao.instance.deleteAllFailed(auth.courier!['id'].toString());
    await loadEntries(); // Reload list
  }

  /// Dismisses a conflict operation.
  Future<void> dismissConflict(String id) async {
    await SyncOperationsDao.instance.updateStatus(id, 'synced', lastError: 'Dismissed by user');
    await loadEntries();
  }

  /// Permanently deletes a single operation.
  Future<void> deleteSingle(String id) async {
    final db = await AppDatabase.getInstance();
    await db.delete('sync_operations', where: 'id = ?', whereArgs: [id]);
    await loadEntries();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _errorMessage(ApiResult<Map<String, dynamic>> result) {
    return switch (result) {
      ApiNetworkError<Map<String, dynamic>>(:final message) => message,
      ApiValidationError<Map<String, dynamic>>(:final message) =>
        message ?? 'Validation error',
      ApiBadRequest<Map<String, dynamic>>(:final message) => message,
      ApiConflict<Map<String, dynamic>>(:final message) => message,
      ApiRateLimited<Map<String, dynamic>>(:final message) => message,
      ApiServerError<Map<String, dynamic>>(:final message) => message,
      _ => 'Unexpected error',
    };
  }

  void _runCleanupSilently() {
    // Lazy import to avoid circular dependency at the module level.
    // ignore: discarded_futures
    _cleanupAsync();
  }

  Future<void> _cleanupAsync() async {
    try {
      final retentionDays = await _ref
          .read(appSettingsProvider)
          .getSyncRetentionDays();
      final syncMs = retentionDays * Duration.millisecondsPerDay;
      const deliveryMs = kLocalDataRetentionDays * Duration.millisecondsPerDay;
      const paidDeliveryMs =
          kPaidDeliveryRetentionDays * Duration.millisecondsPerDay;
      await Future.wait([
        // Do not delete from SyncOperationsDao aggressively yet, it might be used by UI history.
        // Wait, retention policy should delete old "synced" operations.
        SyncOperationsDao.instance.deleteOldSynced(syncMs),
        LocalDeliveryDao.instance.deleteOldSynced(
          deliveryMs,
          paidRetentionMs: paidDeliveryMs,
        ),
      ]);
    } catch (_) {
      // Cleanup failures are non-critical — silently ignored.
    }
  }
}
