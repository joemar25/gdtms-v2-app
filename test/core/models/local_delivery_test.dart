import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';

void main() {
  group('LocalDelivery', () {
    test('fromApiItem handles product field correctly', () {
      final json = {
        'barcode': 'TEST123456',
        'job_order': 'JO-001',
        'product': 'SBC STANDARD',
        'mail_type': 'STANDARD',
        'recipient_name': 'JUAN DELA CRUZ',
        'recipient_address': 'Manila, Philippines',
      };

      final delivery = LocalDelivery.fromApiItem(json);

      expect(delivery.barcode, 'TEST123456');
      expect(delivery.jobOrder, 'JO-001');
      expect(delivery.product, 'SBC STANDARD');
      expect(delivery.mailType, 'STANDARD');
    });

    test('toDeliveryMap includes canonical product and mail_type keys', () {
      final delivery = LocalDelivery(
        barcode: 'TEST123456',
        jobOrder: 'JO-001',
        product: 'SBC STANDARD',
        mailType: 'STANDARD',
        recipientName: 'JUAN DELA CRUZ',
        deliveryAddress: 'Manila, Philippines',
        deliveryStatus: 'FOR_DELIVERY',
        createdAt: 123456789,
        updatedAt: 123456789,
        rawJson: '{}',
      );

      final map = delivery.toDeliveryMap();

      expect(map['barcode'], 'TEST123456');
      expect(map['job_order'], 'JO-001');
      expect(map['product'], 'SBC STANDARD');
      expect(map['mail_type'], 'STANDARD');
    });

    test('toDb and fromDb preserve product field', () {
      final delivery = LocalDelivery(
        barcode: 'TEST123456',
        product: 'SBC STANDARD',
        mailType: 'STANDARD',
        recipientName: 'JUAN DELA CRUZ',
        deliveryAddress: 'Manila, Philippines',
        deliveryStatus: 'FOR_DELIVERY',
        createdAt: 123456789,
        updatedAt: 123456789,
        rawJson: '{}',
      );

      final dbMap = delivery.toDb();
      final fromDb = LocalDelivery.fromDb(dbMap);

      expect(fromDb.product, 'SBC STANDARD');
      expect(fromDb.mailType, 'STANDARD');
    });
  });
}
