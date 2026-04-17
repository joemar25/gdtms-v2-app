// DOCS: docs/core/sync.md — update that file when you edit this one.

// =============================================================================
// sync_manager.dart
// =============================================================================
//
// [IMPORTANT] Exclusive to Deliveries:
//   This manager is strictly for synchronizing delivery status updates and
//   associated media (POD, Selfie, Signature).
//   DO NOT use this for profile changes or Courier authentication updates.
// =============================================================================

import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:retry/retry.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/services/error_log_service.dart';
import 'package:fsi_courier_app/core/services/time_validation_service.dart';
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

class SyncManagerNotifier extends Notifier<SyncState> {
  bool _disposed = false;

  @override
  SyncState build() {
    ref.onDispose(() => _disposed = true);
    return const SyncState.initial();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Loads all queue entries from SQLite and refreshes [state.entries].
  /// Call this when opening the Sync screen.
  ///
  /// After loading, non-blockingly checks whether any synced entry has passed
  /// its retention deadline and runs auto-cleanup if needed.
  Future<void> loadEntries() async {
    final courier = ref.read(authProvider).courier ?? {};
    final courierId = courier['id']?.toString() ?? '';
    final entries = await SyncOperationsDao.instance.getAll(courierId);
    if (!_disposed) state = state.copyWith(entries: entries);
    _autoCleanupIfEligible(entries);
  }

  /// Checks whether any synced entry in [entries] has passed its retention
  /// deadline using the same cutoff logic as [deleteOldSynced].
  /// If eligible entries are found, runs cleanup and reloads the list.
  void _autoCleanupIfEligible(List<SyncOperation> entries) {
    if (entries.every((e) => e.status != 'synced')) return;
    // ignore: discarded_futures
    _autoCleanupCheck(entries);
  }

  Future<void> _autoCleanupCheck(List<SyncOperation> entries) async {
    try {
      final retentionDays = await ref
          .read(appSettingsProvider)
          .getSyncRetentionDays();
      final synced = entries.where((e) => e.status == 'synced');

      final int cutoff;
      if (retentionDays <= 0) {
        // Debug 1-min mode: rolling 1-minute cutoff.
        cutoff =
            DateTime.now().millisecondsSinceEpoch -
            const Duration(minutes: 1).inMilliseconds;
      } else {
        // Midnight-aligned: same formula as deleteOldSynced.
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);
        cutoff = todayMidnight
            .subtract(Duration(days: retentionDays - 1))
            .millisecondsSinceEpoch;
      }

      if (!synced.any((e) => e.createdAt < cutoff)) return;

      // Eligible entries exist — run cleanup then refresh the list.
      await _cleanupAsync();
      await loadEntries();
    } catch (_) {
      // Non-critical — silently ignored.
    }
  }

  /// Processes every [pending] queue entry sequentially.
  ///
  /// - Skips silently if already [isSyncing].
  /// - Updates [state] in real time so the UI stays reactive.
  /// - Runs [CleanupService] when all entries have been processed.
  Future<void> processQueue() async {
    if (state.isSyncing) return;

    final courier = ref.read(authProvider).courier ?? {};
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
      if (_disposed) break;

      state = state.copyWith(
        currentBarcode: entry.barcode,
        lastMessage: 'Updating delivery ${entry.barcode} to server…',
      );

      // Profile updates are online-only direct API calls (PATCH /me).
      // They must never enter the delivery sync pipeline. Auto-resolve any
      // stale UPDATE_PROFILE entries so they disappear from the queue.
      if (entry.operationType == 'UPDATE_PROFILE') {
        await SyncOperationsDao.instance.updateStatus(
          entry.id,
          'synced',
          lastAttemptAt: DateTime.now().millisecondsSinceEpoch,
          lastError:
              'Resolved: profile updates use direct API, not sync queue.',
        );
        state = state.copyWith(processed: state.processed + 1);
        continue;
      }

      final attemptAt = DateTime.now().millisecondsSinceEpoch;
      await SyncOperationsDao.instance.updateStatus(
        entry.id,
        'processing',
        lastAttemptAt: attemptAt,
      );

      try {
        final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;

        // ── Upload any pending media (stored offline as local files) ────────────
        if (entry.mediaPathsJson != null && entry.mediaPathsJson!.isNotEmpty) {
          final pendingMedia =
              jsonDecode(entry.mediaPathsJson!) as Map<String, dynamic>;
          if (pendingMedia.isNotEmpty) {
            state = state.copyWith(
              lastMessage:
                  'Uploading media for ${entry.barcode} (${pendingMedia.length} file${pendingMedia.length == 1 ? '' : 's'})…',
            );
            final uploadedImages = <Map<String, dynamic>>[];
            final api = ref.read(apiClientProvider);
            final uploadPath = '/deliveries/${entry.barcode}/media';

            debugPrint(
              '[SYNC] media queue for ${entry.barcode}: ${pendingMedia.keys.join(', ')}',
            );

            int uploadedCount = 0;
            int failedCount = 0;

            for (final kv in pendingMedia.entries) {
              // Strip only trailing numeric suffixes (e.g., pod_1 -> pod,
              // selfie_2 -> selfie) while preserving compound types like
              // recipient_signature. split('_').first would wrongly reduce
              // recipient_signature -> recipient.
              final baseType = kv.key.toString().replaceAll(
                RegExp(r'_\d+$'),
                '',
              );
              final filePath = kv.value.toString();

              final file = File(filePath);
              if (!await file.exists()) {
                debugPrint(
                  '[SYNC] media file missing for $baseType — skipping: $filePath',
                );
                await ErrorLogService.warning(
                  context: 'sync',
                  message:
                      'Media file missing for ${entry.barcode} ($baseType)',
                  detail: 'Path not found: $filePath',
                  barcode: entry.barcode,
                );
                failedCount++;
                continue;
              }

              final bytes = await file.readAsBytes();
              debugPrint(
                '[SYNC] uploading $baseType (${bytes.length}b) for ${entry.barcode}',
              );
              final ext = filePath.endsWith('.png') ? 'png' : 'jpg';
              final filename = '$baseType.$ext';

              ApiResult<Map<String, dynamic>> result = await api
                  .uploadMedia<Map<String, dynamic>>(
                    uploadPath,
                    bytes: bytes,
                    filename: filename,
                    type: baseType,
                    parser: (d) {
                      if (d is Map<String, dynamic>) {
                        return d;
                      }
                      if (d is Map) {
                        return d.map((k, v) => MapEntry(k.toString(), v));
                      }
                      return <String, dynamic>{};
                    },
                  );

              if (result is ApiSuccess<Map<String, dynamic>>) {
                final inner = result.data['data'];
                final url =
                    (inner is Map
                            ? inner['url'] ??
                                  inner['signed_url'] ??
                                  inner['file'] ??
                                  inner['path']
                            : result.data['url'] ?? result.data['signed_url'])
                        ?.toString();

                if (url != null && url.isNotEmpty) {
                  debugPrint('[SYNC] $baseType uploaded → $url');
                  uploadedCount++;
                  if (baseType == 'recipient_signature') {
                    payload['recipient_signature'] = url;
                  } else {
                    // Build the delivery_images entry exactly per API spec:
                    // { "file": "<url>", "type": "<pod|selfie|recipient>" }
                    uploadedImages.add({'file': url, 'type': baseType});
                  }
                } else {
                  failedCount++;
                  debugPrint(
                    '[SYNC] $baseType upload succeeded but URL was null/empty — dropped',
                  );
                  await ErrorLogService.warning(
                    context: 'sync',
                    message:
                        'Upload URL missing for ${entry.barcode} ($baseType)',
                    detail:
                        'ApiSuccess returned null/empty URL. data=${result.data}',
                    barcode: entry.barcode,
                  );
                }
              } else {
                failedCount++;
                debugPrint('[SYNC] $baseType upload failed: $result');
                await ErrorLogService.warning(
                  context: 'sync',
                  message: 'Upload failed for ${entry.barcode} ($baseType)',
                  detail: result.toString(),
                  barcode: entry.barcode,
                );
              }
            }
            debugPrint(
              '[SYNC] upload summary for ${entry.barcode}: '
              'uploaded=$uploadedCount failed=$failedCount '
              'types=[${uploadedImages.map((e) => e['type']).join(', ')}]',
            );

            if (uploadedImages.isNotEmpty) {
              final existing = payload['delivery_images'];
              final merged = <Map<String, dynamic>>[
                if (existing is List)
                  ...existing.whereType<Map<String, dynamic>>(),
                ...uploadedImages,
              ];
              payload['delivery_images'] = merged;
              debugPrint(
                '[SYNC] delivery_images payload: '
                '${merged.map((e) => '{file:${(e['file'] as String?)?.substring(0, 40)}..., type:${e['type']}}').join(', ')}',
              );
            }

            final hasSignature = payload.containsKey('recipient_signature');
            final hasUploadedImages = uploadedImages.isNotEmpty;
            final anyUploaded = hasSignature || hasUploadedImages;

            // If there were pending media items but NONE produced an uploaded
            // result (no delivery_images, no signature, no profile picture URL),
            // mark the operation as failed and retry.
            // Partial success (some images uploaded, some failed) is allowed —
            // we proceed with the PATCH so the delivery status is updated even
            // if a photo was temporarily unavailable.
            if (pendingMedia.isNotEmpty && !anyUploaded) {
              final newRetryCount = entry.retryCount + 1;
              const mediaError =
                  'Media upload failed — no proof photos could be uploaded.';
              debugPrint(
                '[SYNC] ALL media uploads failed for ${entry.barcode} '
                '(${pendingMedia.length} files) — marking failed, will retry.',
              );
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
                lastMessage:
                    'Media upload failed for ${entry.barcode}. Will retry.',
              );
              continue;
            }
          }
        }

        // Log the exact payload sent to the server for debugging.
        debugPrint(
          '[SYNC] PATCH payload for ${entry.barcode}: '
          'status=${payload['delivery_status']} '
          'images=${(payload['delivery_images'] as List?)?.length ?? 0} '
          'signature=${payload.containsKey('recipient_signature')} '
          'keys=[${payload.keys.join(', ')}]',
        );

        final result = await retry<ApiResult<Map<String, dynamic>>>(
          () async {
            final path = '/deliveries/${entry.barcode}';
            final res = await ref
                .read(apiClientProvider)
                .patch<Map<String, dynamic>>(
                  path,
                  data: payload,
                  extraHeaders: {
                    'X-Request-ID': entry.id,
                  }, // Use op UUID for idempotency
                  parser: parseApiMap,
                );
            if (res is ApiRateLimited) {
              // Respect the Retry-After header before letting retry() fire again.
              final waitSecs = (res as ApiRateLimited).retryAfterSeconds ?? 60;
              debugPrint(
                '[SYNC] 429 rate-limited for ${entry.barcode} — waiting ${waitSecs}s (Retry-After)',
              );
              await Future.delayed(Duration(seconds: waitSecs));
              throw Exception(
                'Rate limited — retried after ${waitSecs}s: ${_errorMessage(res)}',
              );
            }
            if (res is ApiNetworkError || res is ApiServerError) {
              throw Exception(
                'Transient error during PATCH: ${_errorMessage(res)}',
              );
            }
            return res;
          },
          maxAttempts: 3,
          delayFactor: const Duration(milliseconds: 500),
        );

        if (_disposed) break;

        if (result is ApiSuccess<Map<String, dynamic>>) {
          final now = DateTime.now().millisecondsSinceEpoch;
          await SyncOperationsDao.instance.updateStatus(
            entry.id,
            'synced',
            lastAttemptAt: now,
          );
          // Advance the sync anchor so any future submission whose device
          // clock is behind this moment is rejected as a backdated update.
          unawaited(TimeValidationService.instance.recordSyncAnchor());
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

          // API v2.7: machine-readable code takes precedence over string matching.
          String? responseCode;
          if (result is ApiConflict<Map<String, dynamic>>) {
            final data = result.data;
            if (data is Map) {
              responseCode = data['code']?.toString();
            }
          }

          // Case 1 — DELIVERY_IMMUTABLE (v2.7 code): item is in a terminal state;
          //   no transition is possible. Always auto-resolve as synced — the courier's
          //   action is moot regardless of intended status.
          final isImmutableStop = responseCode == 'DELIVERY_IMMUTABLE';

          // Case 1b — Legacy: string-match fallback for older API versions that lacked
          //   the machine-readable code. Only auto-resolve for DELIVERED intent.
          final wasIntendingToDeliver =
              payload['delivery_status']?.toString().toUpperCase() ==
              'DELIVERED';
          final isDeliveredImmutableLegacy =
              !isImmutableStop &&
              errorMsg.toLowerCase().contains('delivered') &&
              errorMsg.toLowerCase().contains('immutable') &&
              wasIntendingToDeliver;

          // Case 2 — Same-status transition: server rejected because the item is
          //   already in the state the courier wanted. Safe to mark as synced.
          final targetStatus =
              payload['delivery_status']?.toString().toLowerCase() ?? '';
          final isSameStatusTransition =
              targetStatus.isNotEmpty &&
              errorMsg.toLowerCase().contains('invalid status transition') &&
              errorMsg.toLowerCase().contains("to '$targetStatus'");

          if (isImmutableStop ||
              isDeliveredImmutableLegacy ||
              isSameStatusTransition) {
            final now = DateTime.now().millisecondsSinceEpoch;
            await SyncOperationsDao.instance.updateStatus(
              entry.id,
              'synced',
              lastAttemptAt: now,
              lastError: 'Resolved: $errorMsg',
            );
            successCount++;
            state = state.copyWith(
              processed: state.processed + 1,
              lastMessage:
                  'Delivery ${entry.barcode} already updated on server.',
            );
          } else {
            await SyncOperationsDao.instance.updateStatus(
              entry.id,
              'conflict',
              lastError: errorMsg,
            );
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
          await SyncOperationsDao.instance.updateStatus(
            entry.id,
            'failed',
            lastError: errorMsg,
            retryCount: newRetryCount,
          );
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
        await SyncOperationsDao.instance.updateStatus(
          entry.id,
          'failed',
          lastError: e.toString(),
          retryCount: newRetryCount,
        );
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

    if (!_disposed && successCount > 0) {
      ref.read(deliveryRefreshProvider.notifier).increment();
    }

    // Run cleanup after every sync cycle (non-blocking concern).
    // Import is deferred at runtime to avoid circular reference at parse time.
    _runCleanupSilently();

    final allEntries = await SyncOperationsDao.instance.getAll(courierId);
    if (!_disposed) {
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
    final auth = ref.read(authProvider);
    if (auth.courier == null) return;
    await SyncOperationsDao.instance.deleteAllFailed(
      auth.courier!['id'].toString(),
    );
    await loadEntries(); // Reload list
  }

  /// Dismisses a conflict operation.
  Future<void> dismissConflict(String id) async {
    await SyncOperationsDao.instance.updateStatus(
      id,
      'synced',
      lastError: 'Dismissed by user',
    );
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
      final retentionDays = await ref
          .read(appSettingsProvider)
          .getSyncRetentionDays();
      const deliveryMs = kLocalDataRetentionDays * Duration.millisecondsPerDay;
      const paidDeliveryMs =
          kPaidDeliveryRetentionDays * Duration.millisecondsPerDay;
      await Future.wait([
        SyncOperationsDao.instance.deleteOldSynced(retentionDays),
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
