// DOCS: docs/development-standards.md
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

import 'package:fsi_courier_app/features/bagsakan/bagsakan_providers.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/services/error_log_service.dart';
import 'package:fsi_courier_app/core/services/time_validation_service.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';

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
    final entries = await ref.read(syncOperationsDaoProvider).getAll(courierId);
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
    final pending = await ref
        .read(syncOperationsDaoProvider)
        .getPending(courierId);
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
    final bagsakanIdRemap = <int, int>{};

    for (final entry in pending) {
      if (_disposed) break;

      final String opLabel = switch (entry.operationType) {
        'CREATE_BAGSAKAN' => 'Creating bagsakan group...',
        'UPDATE_BAGSAKAN_GROUP' => 'Updating bagsakan metadata...',
        'DELETE_BAGSAKAN_GROUP' => 'Deleting bagsakan group...',
        'ASSIGN_TO_BAGSAKAN' => 'Assigning items to bagsakan...',
        'UNASSIGN_FROM_BAGSAKAN' => 'Unassigning items from bagsakan...',
        'SUBMIT_BAGSAKAN' => 'Submitting bagsakan group...',
        _ => 'Updating delivery ${entry.barcode} to server...',
      };

      state = state.copyWith(
        currentBarcode: entry.barcode,
        lastMessage: opLabel,
      );

      // Profile updates are online-only direct API calls (PATCH /me).
      // They must never enter the delivery sync pipeline. Auto-resolve any
      // stale UPDATE_PROFILE entries so they disappear from the queue.
      if (entry.operationType == 'UPDATE_PROFILE') {
        await ref
            .read(syncOperationsDaoProvider)
            .updateStatus(
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
      await ref
          .read(syncOperationsDaoProvider)
          .updateStatus(entry.id, 'processing', lastAttemptAt: attemptAt);

      try {
        final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;

        _applyInMemoryBagsakanRemap(payload, bagsakanIdRemap);

        final groupIdForOp = _extractBagsakanGroupId(entry, payload);
        final isDependentBagsakanOp =
            entry.operationType == 'UPDATE_BAGSAKAN_GROUP' ||
            entry.operationType == 'ASSIGN_TO_BAGSAKAN' ||
            entry.operationType == 'UNASSIGN_FROM_BAGSAKAN' ||
            entry.operationType == 'DELETE_BAGSAKAN_GROUP' ||
            entry.operationType == 'SUBMIT_BAGSAKAN';

        if (isDependentBagsakanOp && groupIdForOp != null) {
          final waitingForCreate = await ref
              .read(syncOperationsDaoProvider)
              .hasUnfinishedCreateBagsakan(
                courierId,
                groupIdForOp,
                excludeOperationId: entry.id,
              );
          if (waitingForCreate) {
            await ref
                .read(syncOperationsDaoProvider)
                .updateStatus(entry.id, 'pending', lastAttemptAt: attemptAt);
            state = state.copyWith(
              processed: state.processed + 1,
              lastMessage:
                  'Waiting for bagsakan group $groupIdForOp creation to sync first.',
            );
            continue;
          }
        }

        // Defer SUBMIT_BAGSAKAN until the propagation source's own status update is synced.
        // This ensures the server has the source data ready for propagation.
        if (entry.operationType == 'SUBMIT_BAGSAKAN') {
          final sourceBarcode = payload['source_barcode']?.toString();
          if (sourceBarcode != null && sourceBarcode.isNotEmpty) {
            final waitingForSource = await ref
                .read(syncOperationsDaoProvider)
                .hasPendingSync(sourceBarcode);
            if (waitingForSource) {
              await ref
                  .read(syncOperationsDaoProvider)
                  .updateStatus(entry.id, 'pending', lastAttemptAt: attemptAt);
              state = state.copyWith(
                processed: state.processed + 1,
                lastMessage:
                    'Waiting for $sourceBarcode status sync before submitting group.',
              );
              continue;
            }
          }
        }

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

            debugPrint(
              '[SYNC] media queue for ${entry.barcode}: ${pendingMedia.keys.join(', ')}',
            );

            int uploadedCount = 0;
            int failedCount = 0;
            final uploadErrors = <String>[];
            for (final kv in pendingMedia.entries) {
              // Strip only trailing numeric suffixes (e.g., pod_1 -> pod,
              // selfie_2 -> selfie) while preserving compound types like
              // recipient_signature. split('_').first would wrongly reduce
              // recipient_signature -> recipient.
              final rawType = kv.key.toString().replaceAll(
                RegExp(r'_\d+$'),
                '',
              );
              final baseType = rawType == 'recipient_signature'
                  ? 'signature'
                  : rawType;
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
                    barcode: entry.barcode,
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
                  if (baseType == 'signature') {
                    payload['recipient_signature'] = url;
                  } else {
                    uploadedImages.add({
                      'file': url,
                      'type': baseType.toUpperCase(),
                    });
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
                // Extract a human-readable message from the ApiResult type.
                final errMsg = switch (result) {
                  ApiServerError(:final message) => 'S3/server error: $message',
                  ApiNetworkError(:final message) => 'Network error: $message',
                  ApiValidationError(:final message) =>
                    'Validation error: ${message ?? result.errors.values.expand((e) => e).join(', ')}',
                  ApiBadRequest(:final message) => 'Bad request: $message',
                  _ => 'Upload failed (${result.runtimeType})',
                };
                uploadErrors.add('$baseType \u2014 $errMsg');
                debugPrint('[SYNC] $baseType upload failed: $errMsg');
                await ErrorLogService.warning(
                  context: 'sync',
                  message: 'Upload failed for ${entry.barcode} ($baseType)',
                  detail: errMsg,
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
              final mediaError = uploadErrors.isNotEmpty
                  ? uploadErrors.join(' | ')
                  : 'Media upload failed \u2014 no proof photos could be uploaded.';
              debugPrint(
                '[SYNC] ALL media uploads failed for ${entry.barcode} '
                '(${pendingMedia.length} files) — marking failed, will retry.',
              );
              await ref
                  .read(syncOperationsDaoProvider)
                  .updateStatus(
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
            final api = ref.read(apiClientProvider);
            final ApiResult<Map<String, dynamic>> res;

            final headers = {'X-Request-ID': entry.id};

            if (entry.operationType == 'CREATE_BAGSAKAN') {
              res = await api.post<Map<String, dynamic>>(
                'bagsakan/groups',
                data: payload,
                extraHeaders: headers,
                parser: parseApiMap,
              );
            } else if (entry.operationType == 'UPDATE_BAGSAKAN_GROUP') {
              final id = payload['id'];
              res = await api.patch<Map<String, dynamic>>(
                'bagsakan/groups/$id',
                data: payload,
                extraHeaders: headers,
                parser: parseApiMap,
              );
            } else if (entry.operationType == 'DELETE_BAGSAKAN_GROUP') {
              final id = payload['id'];
              res = await api.delete<Map<String, dynamic>>(
                'bagsakan/groups/$id',
                extraHeaders: headers,
                parser: parseApiMap,
              );
            } else if (entry.operationType == 'ASSIGN_TO_BAGSAKAN') {
              final id = payload['group_id'];
              res = await api.post<Map<String, dynamic>>(
                'bagsakan/groups/$id/assign',
                data: payload,
                extraHeaders: headers,
                parser: parseApiMap,
              );
            } else if (entry.operationType == 'UNASSIGN_FROM_BAGSAKAN') {
              final id = payload['group_id'];
              res = await api.post<Map<String, dynamic>>(
                'bagsakan/groups/$id/unassign',
                data: payload,
                extraHeaders: headers,
                parser: parseApiMap,
              );
            } else if (entry.operationType == 'SUBMIT_BAGSAKAN') {
              final id = payload['group_id'];
              // api v3.8: strip local-only helper fields before sending.
              // server handles barcodes propagation automatically.
              final apiPayload = Map<String, dynamic>.from(payload)
                ..remove('group_id')
                ..remove('barcodes');
              res = await api.post<Map<String, dynamic>>(
                'bagsakan/groups/$id/submit',
                data: apiPayload,
                extraHeaders: headers,
                parser: parseApiMap,
              );
            } else {
              res = await api.patch<Map<String, dynamic>>(
                'deliveries/${entry.barcode}',
                data: payload,
                extraHeaders: headers,
                parser: parseApiMap,
              );
            }

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
            final isBagsakanNotFound =
                entry.operationType != 'CREATE_BAGSAKAN' &&
                entry.barcode.startsWith('BAGSAKAN_') &&
                _errorMessage(
                  res,
                ).toLowerCase().contains('bagsakan group not found');

            if ((res is ApiNetworkError || res is ApiServerError) &&
                !isBagsakanNotFound) {
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

          if (entry.operationType == 'CREATE_BAGSAKAN') {
            final localGroupId = (payload['id'] as num?)?.toInt();
            final responseData = result.data['data'];
            final serverGroupId = responseData is Map
                ? (responseData['id'] as num?)?.toInt()
                : null;

            if (localGroupId != null &&
                serverGroupId != null &&
                localGroupId != serverGroupId) {
              await ref
                  .read(bagsakanDaoProvider)
                  .remapGroupId(
                    fromGroupId: localGroupId,
                    toGroupId: serverGroupId,
                  );
              bagsakanIdRemap[localGroupId] = serverGroupId;

              // Also update the UI-facing remap provider so open screens can redirect
              // to the new server-backed ID immediately.
              ref
                  .read(bagsakanIdRemapProvider.notifier)
                  .updateRemap(localGroupId, serverGroupId);
              debugPrint(
                '[SYNC] remapped local bagsakan id $localGroupId -> server id $serverGroupId',
              );
            }
          }

          await ref
              .read(syncOperationsDaoProvider)
              .updateStatus(entry.id, 'synced', lastAttemptAt: now);
          // Advance the sync anchor so any future submission whose device
          // clock is behind this moment is rejected as a backdated update.
          unawaited(TimeValidationService.instance.recordSyncAnchor());
          final deliveryData = result.data['data'];
          if (!entry.barcode.startsWith('BAGSAKAN_')) {
            if (deliveryData is Map<String, dynamic>) {
              await ref
                  .read(localDeliveryDaoProvider)
                  .updateFromJson(entry.barcode, deliveryData);
            } else {
              // Authoritative Fallback: Fetch the final server state
              // to ensure the local DB is perfectly in sync with field-level
              // updates (e.g. server-side timestamps, piece count corrections).
              await _refreshDeliveryFromServer(entry.barcode);
            }
          } else {
            // Handle Bagsakan items cleanup
            if (entry.operationType == 'ASSIGN_TO_BAGSAKAN' ||
                entry.operationType == 'UNASSIGN_FROM_BAGSAKAN' ||
                entry.operationType == 'DELETE_BAGSAKAN_GROUP' ||
                entry.operationType == 'SUBMIT_BAGSAKAN') {
              _cleanupBagsakanItems(payload, entry.operationType);
            }
          }
          successCount++;
          String successMsg = 'Delivery ${entry.barcode} successfully synced.';
          if (entry.operationType == 'SUBMIT_BAGSAKAN') {
            final data = result.data['data'];
            if (data is Map) {
              final updated = data['updated_deliveries'] ?? 0;
              final timeline = data['timeline_created'] ?? 0;
              final media = data['media_attached'] ?? 0;
              successMsg =
                  'Bagsakan submitted: $updated deliveries updated, $timeline timeline rows created, $media media attached.';
              debugPrint('[SYNC] $successMsg');
            }
          }
          state = state.copyWith(
            processed: state.processed + 1,
            lastMessage: successMsg,
          );
        } else if (result is ApiConflict<Map<String, dynamic>> ||
            result is ApiBadRequest<Map<String, dynamic>> ||
            result is ApiValidationError<Map<String, dynamic>> ||
            result is ApiNotFound<Map<String, dynamic>>) {
          // Terminal conflicts/errors from server -> abandon retry, mark as conflict or resolve automatically
          final errorMsg = _errorMessage(result);

          // API v2.7: machine-readable code takes precedence over string matching.
          String? responseCode;
          if (result is ApiConflict<Map<String, dynamic>>) {
            final data = result.data;
            if (data is Map) responseCode = data['code']?.toString();
          } else if (result is ApiBadRequest<Map<String, dynamic>>) {
            final data = result.data;
            if (data is Map) responseCode = data['code']?.toString();
          } else if (result is ApiServerError<Map<String, dynamic>>) {
            final data = result.data;
            if (data is Map) responseCode = data['code']?.toString();
          } else if (result is ApiValidationError<Map<String, dynamic>>) {
            final data = result.data;
            if (data is Map) responseCode = data['code']?.toString();
          }

          // Case 1 — DELIVERY_IMMUTABLE (v2.7 code): item is in a terminal state;
          //   no transition is possible. Always auto-resolve as synced — the courier's
          //   action is moot regardless of intended status.
          final isImmutableStop = responseCode == 'DELIVERY_IMMUTABLE';

          // Case 1b — Legacy: string-match fallback for older API versions that lacked
          //   the machine-readable code. Only auto-resolve for DELIVERED intent.
          final wasIntendingToDeliver =
              payload['delivery_status']?.toString().toUpperCase() ==
              kStatusDelivered;
          final isDeliveredImmutableLegacy =
              !isImmutableStop &&
              errorMsg.toLowerCase().contains('delivered') &&
              errorMsg.toLowerCase().contains('immutable') &&
              wasIntendingToDeliver;

          // Case 2 — Same-status transition: server rejected because the item is
          //   already in the state the courier wanted. Safe to mark as synced.
          final isSameStatusTransitionCode =
              responseCode == 'SAME_STATUS_TRANSITION';

          // Case 3 — Duplicate-request idempotency: same X-Request-ID was already
          //   processed. The server returns the original success payload.
          final isDuplicateRequestCode = responseCode == 'DUPLICATE_REQUEST';

          // Case 4 — Max FAILED_DELIVERY attempts reached.
          //   Backend now sends code=MAX_ATTEMPTS_REACHED (CourierMobileApiService fix).
          //   Message-sniff is kept as fallback for older API versions.
          //   Auto-resolve so the Sync screen shows the server's human-readable
          //   message (stored in lastError) instead of a confusing "conflict" label.
          //   The delivery is still correctly locked by isVisibleToRider (attempts >= 3).
          final isMaxAttemptsReached =
              responseCode == 'MAX_ATTEMPTS_REACHED' ||
              ((result is ApiBadRequest<Map<String, dynamic>>) &&
                  (errorMsg.toLowerCase().contains('maximum') ||
                      errorMsg.toLowerCase().contains('attempts')));

          // Case 5 — Resource already gone (404).
          //   For DELETE_BAGSAKAN_GROUP: already deleted on server — success.
          //   For delivery updates: orphaned barcode (MasterList exists, no Delivery row)
          //   — auto-resolve so it doesn't stay stuck as "conflict" forever.
          final isAlreadyDeleted =
              result is ApiNotFound<Map<String, dynamic>> &&
              entry.operationType == 'DELETE_BAGSAKAN_GROUP';

          final isOrphanedDelivery =
              result is ApiNotFound<Map<String, dynamic>> &&
              !entry.barcode.startsWith('BAGSAKAN_');

          // Case 6 — Bagsakan already submitted: terminal state for group.
          final isAlreadySubmitted =
              responseCode == 'BAGSAKAN_ALREADY_SUBMITTED';

          final shouldAutoResolve =
              isImmutableStop ||
              isDeliveredImmutableLegacy ||
              isSameStatusTransitionCode ||
              isDuplicateRequestCode ||
              isMaxAttemptsReached ||
              isAlreadyDeleted ||
              isOrphanedDelivery ||
              isAlreadySubmitted;

          if (shouldAutoResolve) {
            final now = DateTime.now().millisecondsSinceEpoch;

            bool dataUpdated = false;
            if (result is ApiConflict<Map<String, dynamic>>) {
              final responseData = result.data;
              final maybeData = responseData is Map
                  ? responseData['data'] ?? responseData
                  : null;
              if (maybeData is Map<String, dynamic> &&
                  !entry.barcode.startsWith('BAGSAKAN_')) {
                await ref
                    .read(localDeliveryDaoProvider)
                    .updateFromJson(entry.barcode, maybeData);
                dataUpdated = true;
              }
            }

            // Authoritative Fallback: If the error didn't return the full object,
            // fetch it now to ensure the local DB reflects the server's truth
            // (effectively reverting the local change if the server rejected it).
            if (!dataUpdated && !entry.barcode.startsWith('BAGSAKAN_')) {
              await _refreshDeliveryFromServer(entry.barcode);
            }

            // Bagsakan auto-resolve cleanup (fixes "ghost dirty" items)
            if (entry.operationType == 'ASSIGN_TO_BAGSAKAN' ||
                entry.operationType == 'UNASSIGN_FROM_BAGSAKAN' ||
                entry.operationType == 'DELETE_BAGSAKAN_GROUP' ||
                entry.operationType == 'SUBMIT_BAGSAKAN') {
              _cleanupBagsakanItems(payload, entry.operationType);
            }

            await ref
                .read(syncOperationsDaoProvider)
                .updateStatus(
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
            String conflictDisplayError = errorMsg;
            String? conflictPayloadJson;

            if (result is ApiConflict<Map<String, dynamic>>) {
              final responseData = result.data;
              if (responseData is Map) {
                final rawConflicts = responseData['already_assigned_barcodes'];
                if (rawConflicts is List && rawConflicts.isNotEmpty) {
                  final conflicts = rawConflicts
                      .map((e) => asStringDynamicMap(e))
                      .where((e) => e.isNotEmpty)
                      .toList();

                  if (conflicts.isNotEmpty) {
                    final mergedPayload = <String, dynamic>{
                      ...payload,
                      'conflict_details': conflicts,
                    };
                    conflictPayloadJson = jsonEncode(mergedPayload);

                    final compactSummary = conflicts
                        .take(3)
                        .map((c) {
                          final bc = (c['barcode']?.toString() ?? '').trim();
                          final group = (c['group_name']?.toString() ?? '')
                              .trim();
                          if (bc.isEmpty) return '';
                          return group.isNotEmpty ? '$bc ($group)' : bc;
                        })
                        .where((s) => s.isNotEmpty)
                        .join(', ');

                    if (compactSummary.isNotEmpty) {
                      conflictDisplayError = '$errorMsg [$compactSummary]';
                    }
                  }
                }
              }
            }

            // CONFIRMATION_CODE_REQUIRED (422): the client now requires a
            // confirmation code for this delivery, but the queued update lacked
            // one (the flag flipped to true after the item was cached offline).
            // Pull the server's current record so the local
            // required_confirmation_code flag is refreshed and the courier can
            // re-open the update screen and re-enter the code.
            if (responseCode == 'CONFIRMATION_CODE_REQUIRED' &&
                !entry.barcode.startsWith('BAGSAKAN_')) {
              await _refreshDeliveryFromServer(entry.barcode);
            }

            await ref
                .read(syncOperationsDaoProvider)
                .updateStatus(
                  entry.id,
                  'conflict',
                  lastError: conflictDisplayError,
                  payloadJson: conflictPayloadJson,
                );
            await ErrorLogService.warning(
              context: 'sync',
              message: 'Conflict on ${entry.barcode}',
              detail: conflictDisplayError,
              barcode: entry.barcode,
            );
            state = state.copyWith(
              processed: state.processed + 1,
              lastMessage:
                  'Conflict on ${entry.barcode}: $conflictDisplayError',
            );
          }
        } else {
          final errorMsg = _errorMessage(result);
          final isBagsakanNotFound =
              entry.operationType != 'CREATE_BAGSAKAN' &&
              entry.barcode.startsWith('BAGSAKAN_') &&
              errorMsg.toLowerCase().contains('bagsakan group not found');

          if (isBagsakanNotFound) {
            final groupId = _extractBagsakanGroupId(entry, payload);
            final localGroup = groupId == null
                ? null
                : await ref.read(bagsakanDaoProvider).getBagsakanGroup(groupId);

            if (localGroup == null) {
              final now = DateTime.now().millisecondsSinceEpoch;
              _cleanupBagsakanItems(payload, entry.operationType);
              await ref
                  .read(syncOperationsDaoProvider)
                  .updateStatus(
                    entry.id,
                    'synced',
                    lastAttemptAt: now,
                    lastError: 'Resolved stale operation: $errorMsg',
                  );
              successCount++;
              state = state.copyWith(
                processed: state.processed + 1,
                lastMessage:
                    'Resolved stale bagsakan operation for ${entry.barcode}.',
              );
              continue;
            }
          }

          final newRetryCount = entry.retryCount + 1;
          await ref
              .read(syncOperationsDaoProvider)
              .updateStatus(
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
        await ref
            .read(syncOperationsDaoProvider)
            .updateStatus(
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

    final allEntries = await ref
        .read(syncOperationsDaoProvider)
        .getAll(courierId);
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
    await ref.read(syncOperationsDaoProvider).resetToPending(id);
    await processQueue();
  }

  /// Clears all failed entries (and their media files) then refreshes the list.
  Future<void> clearFailed() async {
    final auth = ref.read(authProvider);
    if (auth.courier == null) return;
    final courierId = auth.courier!['id'].toString();
    final db = await AppDatabase.getInstance();
    final rows = await db.query(
      'sync_operations',
      columns: ['media_paths_json'],
      where: "courier_id = ? AND status = 'failed'",
      whereArgs: [courierId],
    );
    for (final row in rows) {
      await _deleteMediaFiles(row['media_paths_json'] as String?);
    }
    await ref.read(syncOperationsDaoProvider).deleteAllFailed(courierId);
    await loadEntries();
  }

  /// Dismisses a conflict operation and reconciles the local delivery to the
  /// server's authoritative state so the local record doesn't stay stuck in the
  /// courier's attempted status (e.g. FAILED_DELIVERY when server rejected it).
  Future<void> dismissConflict(String id) async {
    final db = await AppDatabase.getInstance();
    final rows = await db.query(
      'sync_operations',
      columns: ['barcode'],
      where: 'id = ?',
      whereArgs: [id],
    );
    final barcode = rows.isNotEmpty ? rows.first['barcode'] as String? : null;

    await ref
        .read(syncOperationsDaoProvider)
        .updateStatus(id, 'synced', lastError: 'Dismissed by user');

    if (barcode != null && !barcode.startsWith('BAGSAKAN_')) {
      await _refreshDeliveryFromServer(barcode);
    }

    await loadEntries();
    if (!_disposed) ref.read(deliveryRefreshProvider.notifier).increment();
  }

  /// Permanently deletes a single operation and its associated media files,
  /// then reconciles the local delivery to the server's authoritative state.
  Future<void> deleteSingle(String id) async {
    final db = await AppDatabase.getInstance();
    final rows = await db.query(
      'sync_operations',
      columns: ['barcode', 'media_paths_json'],
      where: 'id = ?',
      whereArgs: [id],
    );
    String? barcode;
    if (rows.isNotEmpty) {
      barcode = rows.first['barcode'] as String?;
      await _deleteMediaFiles(rows.first['media_paths_json'] as String?);
    }
    await db.delete('sync_operations', where: 'id = ?', whereArgs: [id]);

    if (barcode != null && !barcode.startsWith('BAGSAKAN_')) {
      await _refreshDeliveryFromServer(barcode);
    }

    await loadEntries();
    if (!_disposed) ref.read(deliveryRefreshProvider.notifier).increment();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _deleteMediaFiles(String? mediaPathsJson) async {
    if (mediaPathsJson == null) return;
    try {
      final map = jsonDecode(mediaPathsJson) as Map<String, dynamic>;
      for (final path in map.values) {
        final f = File(path as String);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }

  int? _extractBagsakanGroupId(
    SyncOperation entry,
    Map<String, dynamic> payload,
  ) {
    final fromPayload =
        (payload['group_id'] as num?)?.toInt() ??
        (payload['id'] as num?)?.toInt();
    if (fromPayload != null) return fromPayload;

    if (!entry.barcode.startsWith('BAGSAKAN_')) return null;
    final raw = entry.barcode.substring('BAGSAKAN_'.length);
    return int.tryParse(raw);
  }

  void _applyInMemoryBagsakanRemap(
    Map<String, dynamic> payload,
    Map<int, int> remap,
  ) {
    if (remap.isEmpty) return;

    final id = (payload['id'] as num?)?.toInt();
    if (id != null && remap.containsKey(id)) {
      payload['id'] = remap[id];
    }

    final groupId = (payload['group_id'] as num?)?.toInt();
    if (groupId != null && remap.containsKey(groupId)) {
      payload['group_id'] = remap[groupId];
    }
  }

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

  /// Marks individual items in a Bagsakan group as 'clean' in the local DB.
  /// Call this when a Bagsakan operation is either successfully synced
  /// or auto-resolved (e.g. Conflict 409).
  void _cleanupBagsakanItems(
    Map<String, dynamic> payload,
    String operationType,
  ) {
    // ignore: discarded_futures
    _cleanupBagsakanItemsAsync(payload, operationType);
  }

  Future<void> _cleanupBagsakanItemsAsync(
    Map<String, dynamic> payload,
    String operationType,
  ) async {
    try {
      final barcodes = payload['barcodes'] as List?;
      final groupId =
          (payload['group_id'] as num?)?.toInt() ??
          (payload['id'] as num?)?.toInt();

      if (barcodes != null) {
        for (final b in barcodes) {
          final barcodeStr = b.toString();
          final hasPending = await ref
              .read(syncOperationsDaoProvider)
              .hasPendingSync(barcodeStr);

          // Force reconcile bagsakan_id during cleanup to ensure consistency
          // even if a concurrent sync-from-api pass cleared it locally.
          if (operationType == 'ASSIGN_TO_BAGSAKAN' && groupId != null) {
            await ref
                .read(bagsakanDaoProvider)
                .forceReconcileItemAssignment(barcodeStr, groupId);
          } else if (operationType == 'UNASSIGN_FROM_BAGSAKAN' ||
              operationType == 'DELETE_BAGSAKAN_GROUP') {
            await ref
                .read(bagsakanDaoProvider)
                .forceReconcileItemAssignment(barcodeStr, null);
          }

          if (!hasPending) {
            if (operationType == 'SUBMIT_BAGSAKAN') {
              // After group submit the server has propagated the source's
              // status/timeline/media to all siblings. Re-fetch each sibling
              // so local DB reflects the server-confirmed state (delivery_status,
              // raw_json, timestamps) and is marked clean in one pass.
              await _refreshDeliveryFromServer(barcodeStr);
            } else {
              await ref.read(localDeliveryDaoProvider).markClean(barcodeStr);
            }
          }
        }
      }

      if (operationType == 'SUBMIT_BAGSAKAN') {
        final source = payload['source_barcode'];
        if (source != null) {
          final sourceStr = source.toString();
          final hasPending = await ref
              .read(syncOperationsDaoProvider)
              .hasPendingSync(sourceStr);
          if (!hasPending) {
            await ref.read(localDeliveryDaoProvider).markClean(sourceStr);
          }
        }
      }
    } catch (e) {
      debugPrint('[SYNC] Failed to cleanup Bagsakan items: $e');
    }
  }

  /// Fetches the latest delivery data for [barcode] from the server and
  /// applies it to the local record via [updateFromJson], which also marks
  /// the row clean. Falls back to [markClean] if the fetch fails so the
  /// sync lock is never left dangling.
  Future<void> _refreshDeliveryFromServer(String barcode) async {
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.get<Map<String, dynamic>>(
        '/deliveries/$barcode',
        parser: parseApiMap,
      );
      if (result is ApiSuccess<Map<String, dynamic>>) {
        final data = result.data['data'];
        if (data is Map<String, dynamic>) {
          await ref
              .read(localDeliveryDaoProvider)
              .updateFromJson(barcode, data);
          debugPrint(
            '[SYNC] refreshed $barcode from server after group submit',
          );
          return;
        }
      }
      debugPrint(
        '[SYNC] refresh $barcode non-success: $result — falling back to markClean',
      );
    } catch (e) {
      debugPrint(
        '[SYNC] refresh $barcode error: $e — falling back to markClean',
      );
    }
    // Fallback: at minimum remove the sync lock so the delivery is usable.
    await ref.read(localDeliveryDaoProvider).markClean(barcode);
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
      await Future.wait([
        ref.read(syncOperationsDaoProvider).deleteOldSynced(retentionDays),
        ref.read(localDeliveryDaoProvider).deleteOldSynced(deliveryMs),
      ]);
    } catch (_) {
      // Cleanup failures are non-critical — silently ignored.
    }
  }
}
