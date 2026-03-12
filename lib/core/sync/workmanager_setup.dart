import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Initialize SQLite
      await AppDatabase.getInstance();

      // 2. Initialize Auth Storage
      final authStorage = AuthStorage();

      // 3. Create isolated ApiClient
      final apiClient = ApiClient(authStorage: authStorage);

      // 4. Do we have a token?
      final token = await authStorage.getToken();
      if (token == null || token.isEmpty) {
        return Future.value(true); // User is logged out, nothing to do
      }

      // 5. Run the background reconcile logic
      await DeliveryBootstrapService.instance.syncFromApi(apiClient);

      return Future.value(true);
    } catch (e) {
      debugPrint('Background sync failed: $e');
      // Returning true ensures it will retry according to backoff policy
      // returning false cancels it for this run. We return true for transient network exceptions.
      return Future.value(true);
    }
  });
}

class BackgroundSyncSetup {
  static const String periodicSyncTask = 'periodicSyncTask';

  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    await Workmanager().registerPeriodicTask(
      'fsi_courier_bg_sync',
      periodicSyncTask,
      frequency: const Duration(minutes: 15), // 15 mins is Android's minimum
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
