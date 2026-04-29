import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';

final localDeliveryDaoProvider = Provider<LocalDeliveryDao>((ref) {
  return LocalDeliveryDao.instance;
});

final syncOperationsDaoProvider = Provider<SyncOperationsDao>((ref) {
  return SyncOperationsDao.instance;
});
