import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';

void main() {
  group('DeliveryCard Rendering', () {
    testWidgets('renders PRODUCT label when product field is present', (
      WidgetTester tester,
    ) async {
      final delivery = {
        'barcode': 'TEST123456',
        'product': 'SBC STANDARD',
        'delivery_status': 'FOR_DELIVERY',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryCard(delivery: delivery, onTap: () {}),
          ),
        ),
      );

      expect(find.text('delivery_card.details.product'), findsOneWidget);
      expect(find.text('SBC STANDARD'), findsAtLeast(1));
    });

    testWidgets('hides MAIL TYPE if it is redundant with PRODUCT', (
      WidgetTester tester,
    ) async {
      final delivery = {
        'barcode': 'TEST123456',
        'product': 'SBC STANDARD',
        'mail_type': 'STANDARD',
        'delivery_status': 'FOR_DELIVERY',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryCard(delivery: delivery, onTap: () {}),
          ),
        ),
      );

      expect(find.text('delivery_card.details.product'), findsOneWidget);
      expect(find.text('SBC STANDARD'), findsAtLeast(1));
      // MAIL TYPE should be hidden because 'STANDARD' is in 'SBC STANDARD'
      expect(find.text('delivery_card.details.mail_type'), findsNothing);
    });

    testWidgets('shows both if they are not redundant', (
      WidgetTester tester,
    ) async {
      final delivery = {
        'barcode': 'TEST123456',
        'product': 'ELITE',
        'mail_type': 'EXPRESS',
        'delivery_status': 'FOR_DELIVERY',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeliveryCard(delivery: delivery, onTap: () {}),
          ),
        ),
      );

      expect(find.text('delivery_card.details.product'), findsOneWidget);
      expect(find.text('ELITE'), findsAtLeast(1));
      expect(find.text('delivery_card.details.mail_type'), findsOneWidget);
      expect(find.text('EXPRESS'), findsOneWidget);
    });

    testWidgets(
      'shows info icon and product even if delivery is locked/delivered',
      (WidgetTester tester) async {
        final delivery = {
          'barcode': 'TEST123456',
          'product': 'PREMIUM',
          'delivery_status': 'DELIVERED',
          '_delivered_at': DateTime.now()
              .subtract(const Duration(days: 2))
              .millisecondsSinceEpoch,
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DeliveryCard(delivery: delivery, onTap: () {}),
            ),
          ),
        );

        // Info icon (info_rounded) should be present
        expect(find.byIcon(Icons.info_rounded), findsOneWidget);

        // Expand to see details
        await tester.tap(find.byType(DeliveryCard));
        await tester.pumpAndSettle();

        // Product should be visible in details
        expect(find.text('delivery_card.details.product'), findsOneWidget);
        expect(find.text('PREMIUM'), findsAtLeast(1));
      },
    );
  });
}
