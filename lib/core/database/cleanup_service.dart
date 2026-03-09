import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/database/delivery_update_dao.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
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
  Future<void> runIfNeeded(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (prefs.getString(_lastCleanupKey) == today) return;

    final syncRetentionDays = await settings.getSyncRetentionDays();
    await run(syncRetentionDays: syncRetentionDays);
    await prefs.setString(_lastCleanupKey, today);
  }

  /// Deletes [synced] queue entries and completed delivery records that exceed
  /// the configured retention window.
  ///
  /// [syncRetentionDays] controls sync-queue history (defaults to
  /// [kDefaultSyncRetentionDays]). Local delivery records always use
  /// [kLocalDataRetentionDays].
  ///
  /// It is safe to call this at any time; pending data is never touched.
  Future<void> run({int? syncRetentionDays}) async {
    final syncMs =
        (syncRetentionDays ?? kDefaultSyncRetentionDays) *
        Duration.millisecondsPerDay;
    final deliveryMs = kLocalDataRetentionDays * Duration.millisecondsPerDay;
    await Future.wait([
      DeliveryUpdateDao.instance.deleteOldSynced(syncMs),
      LocalDeliveryDao.instance.deleteOldSynced(deliveryMs),
    ]);
  }
}
