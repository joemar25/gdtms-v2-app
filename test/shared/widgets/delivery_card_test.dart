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
      await tester.pump();

      expect(find.text('PRODUCT'), findsOneWidget);
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
      await tester.pump();

      expect(find.text('PRODUCT'), findsOneWidget);
      expect(find.text('SBC STANDARD'), findsAtLeast(1));
      // v3.7: mail_type is no longer displayed as a separate label row.
      expect(find.text('MAIL TYPE'), findsNothing);
    });

    testWidgets('shows PRODUCT label regardless of mail_type value', (
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
      await tester.pump();

      expect(find.text('PRODUCT'), findsOneWidget);
      expect(find.text('ELITE'), findsAtLeast(1));
      // v3.7: mail_type is not displayed as a separate label row.
      expect(find.text('MAIL TYPE'), findsNothing);
    });

    testWidgets('hides info icon when delivery is locked/delivered for privacy', (
      WidgetTester tester,
    ) async {
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
      await tester.pump();

      // STRICT RULE: Info icon must be HIDDEN for locked/finalized items.
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.info_rounded), findsNothing);

      // Product label and value should still be visible in the expanded detail section.
      expect(find.text('PRODUCT'), findsOneWidget);
      expect(find.text('PREMIUM'), findsAtLeast(1));
    });
  });
}
