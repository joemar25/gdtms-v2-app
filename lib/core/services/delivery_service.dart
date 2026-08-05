// DOCS: docs/development-standards.md
// DOCS: docs/core/services.md — update that file when you edit this one.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';

/// A5: feature service over raw `apiClientProvider` for the delivery feature.
///
/// Offline-first writes for delivery status updates go through the sync
/// queue (`SyncOperationsDao` + `SyncWriteCoordinator`), not this service —
/// this only wraps the one direct read call the delivery UI makes.
class DeliveryService {
  const DeliveryService(this._api);

  final ApiClient _api;

  /// GET /deliveries/{barcode} — used by the delivery update screen to
  /// refresh a single delivery's detail before showing the update form.
  Future<ApiResult<Map<String, dynamic>>> getDeliveryDetail(String barcode) {
    return _api.get<Map<String, dynamic>>(
      '/deliveries/$barcode',
      parser: parseApiMap,
    );
  }
}

final deliveryServiceProvider = Provider<DeliveryService>((ref) {
  return DeliveryService(ref.read(apiClientProvider));
});
