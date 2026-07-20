import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';

void main() {
  group('DeliveryBootstrapService performance constants', () {
    test('P2 per_page is at least 100 to cut RTTs vs legacy 50', () {
      expect(DeliveryBootstrapService.kSyncPerPage, greaterThanOrEqualTo(100));
      expect(DeliveryBootstrapService.kSyncPerPage, lessThanOrEqualTo(200));
    });
  });
}
