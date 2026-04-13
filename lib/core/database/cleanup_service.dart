// DOCS: docs/core/database.md — update that file when you edit this one.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';

/// Removes old synced data from both SQLite tables.
///
/// **Safety guarantee**: records that have not been successfully synchronised
/// ([pending] or [syncing]) are never deleted.
class CleanupService {
  CleanupService._();

  static final CleanupService instance = CleanupService._();

  static const _lastCleanupKey = 'last_cleanup_date';

  /// Runs cleanup at most once per calendar day.
  ///
  /// Reads the courier's configured [syncRetentionDays] from [settings].
  /// If cleanup already ran today the call is a no-op.
  ///
  /// Exception: when [syncRetentionDays] == 0 (debug 1-minute mode) the
  /// once-per-day gate is bypassed so cleanup runs on every call, allowing
  /// rapid testing of the auto-removal flow.
  Future<void> runIfNeeded(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final syncRetentionDays = await settings.getSyncRetentionDays();

    // Normal mode: skip if cleanup already ran today.
    if (syncRetentionDays > 0) {
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (prefs.getString(_lastCleanupKey) == today) return;
    }

    await run(syncRetentionDays: syncRetentionDays);

    // Only record the run date in normal mode; debug mode always re-runs.
    if (syncRetentionDays > 0) {
      final now = DateTime.now();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await prefs.setString(_lastCleanupKey, today);
    }
  }

  /// Deletes [synced] queue entries and completed delivery records that exceed
  /// the configured retention window.
  ///
  /// [syncRetentionDays] controls sync-queue history (defaults to
  /// [kDefaultSyncRetentionDays]). Local delivery records always use
  /// [kLocalDataRetentionDays], except for records that have been paid —
  /// those use the shorter [kPaidDeliveryRetentionDays] window for privacy.
  ///
  /// mar-note: TWO retention windows apply to delivered records:
  ///   • Unpaid delivered → kLocalDataRetentionDays (3 days). Gives the courier
  ///     time to review and request payout before the record is auto-removed.
  ///   • Paid delivered → kPaidDeliveryRetentionDays (1 day). After a payout is
  ///     confirmed the record is a liability: it contains personal data (name,
  ///     address, contact) and could be used by a dishonest courier to fake a
  ///     re-claim. Deleting it after 1 day closes that window.
  ///     After deletion, getByBarcode returns null — the record effectively
  ///     does not exist on the device. Any scan or wallet lookup by the courier
  ///     yields nothing, which is intentional.
  ///
  /// It is safe to call this at any time; pending data is never touched.
  Future<void> run({int? syncRetentionDays}) async {
    final days = syncRetentionDays ?? kDefaultSyncRetentionDays;
    final deliveryMs = kLocalDataRetentionDays * Duration.millisecondsPerDay;
    debugPrint(
      '[CleanupService] run: retentionDays=$days, '
      'deliveryMs=$deliveryMs (${kLocalDataRetentionDays}d), '
      'cutoff=${DateTime.now().subtract(Duration(milliseconds: deliveryMs))}',
    );
    const paidDeliveryMs =
        kPaidDeliveryRetentionDays * Duration.millisecondsPerDay;
    final results = await Future.wait([
      SyncOperationsDao.instance.deleteOldSynced(days),
      LocalDeliveryDao.instance.deleteOldSynced(
        deliveryMs,
        paidRetentionMs: paidDeliveryMs,
      ),
    ]);

    final syncCount = results[0];
    final deliveryCount = results[1];

    if (syncCount > 0 || deliveryCount > 0) {
      debugPrint(
        '[CleanupService] Deleted $syncCount old sync '
        'operations and $deliveryCount old deliveries.',
      );
    }
  }
}
