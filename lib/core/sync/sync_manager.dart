import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/database/delivery_update_dao.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/delivery_update_entry.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
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
  final List<DeliveryUpdateEntry> entries;

  /// Human-readable status message shown in the Sync screen header.
  final String? lastMessage;

  SyncState copyWith({
    bool? isSyncing,
    Object? currentBarcode = _sentinel,
    int? processed,
    int? total,
    List<DeliveryUpdateEntry>? entries,
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
      lastMessage:
          lastMessage == _sentinel ? this.lastMessage : lastMessage as String?,
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
    final entries = await DeliveryUpdateDao.instance.getAll();
    if (mounted) state = state.copyWith(entries: entries);
  }

  /// Processes every [pending] queue entry sequentially.
  ///
  /// - Skips silently if already [isSyncing].
  /// - Updates [state] in real time so the UI stays reactive.
  /// - Runs [CleanupService] when all entries have been processed.
  Future<void> processQueue() async {
    if (state.isSyncing) return;

    final pending = await DeliveryUpdateDao.instance.getPending();
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

      await DeliveryUpdateDao.instance.markSyncing(entry.id!);

      try {
        final payload =
            jsonDecode(entry.payloadJson) as Map<String, dynamic>;

        final result = await _ref
            .read(apiClientProvider)
            .patch<Map<String, dynamic>>(
              '/deliveries/${entry.barcode}',
              data: payload,
              parser: parseApiMap,
            );

        if (!mounted) break;

        if (result is ApiSuccess<Map<String, dynamic>>) {
          await DeliveryUpdateDao.instance.markSynced(entry.id!);
          final deliveryData = result.data['data'];
          if (deliveryData is Map<String, dynamic>) {
            await LocalDeliveryDao.instance.updateFromJson(
              entry.barcode,
              deliveryData,
            );
          } else {
            final status = payload['delivery_status']?.toString();
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
        } else {
          final errorMsg = _errorMessage(result);
          await DeliveryUpdateDao.instance.markFailed(entry.id!, errorMsg);
          state = state.copyWith(
            processed: state.processed + 1,
            lastMessage: 'Failed to sync ${entry.barcode}: $errorMsg',
          );
        }
      } catch (e) {
        await DeliveryUpdateDao.instance.markFailed(
          entry.id!,
          e.toString(),
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

    final allEntries = await DeliveryUpdateDao.instance.getAll();
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

  /// Resets a single [failed] entry back to [pending] and immediately
  /// processes the queue. Intended for manual retry from the Sync screen.
  Future<void> retrySingle(int id) async {
    if (state.isSyncing) return;
    await DeliveryUpdateDao.instance.resetToPending(id);
    await processQueue();
  }

  /// Permanently deletes all [failed] queue entries and refreshes the list.
  /// Only intended for debug / developer use.
  Future<void> clearFailed() async {
    await DeliveryUpdateDao.instance.deleteAllFailed();
    await loadEntries();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _errorMessage(ApiResult<Map<String, dynamic>> result) {
    return switch (result) {
      ApiNetworkError<Map<String, dynamic>>(:final message) => message,
      ApiValidationError<Map<String, dynamic>>(:final message) =>
        message ?? 'Validation error',
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
      final retentionDays =
          await _ref.read(appSettingsProvider).getSyncRetentionDays();
      final syncMs = retentionDays * Duration.millisecondsPerDay;
      const deliveryMs = kLocalDataRetentionDays * Duration.millisecondsPerDay;
      await Future.wait([
        DeliveryUpdateDao.instance.deleteOldSynced(syncMs),
        LocalDeliveryDao.instance.deleteOldSynced(deliveryMs),
      ]);
    } catch (_) {
      // Cleanup failures are non-critical — silently ignored.
    }
  }
}
