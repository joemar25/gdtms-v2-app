// Regression tests for DeliverySectionHeader layout rules.
//
// Rules enforced (see docs/development-standards.md — Dynamic Design §2):
//   • DeliverySectionHeader contains Row+Expanded internally, so it MUST be
//     wrapped in Expanded/Flexible when placed as a direct child of a Row.
//   • Placing it bare in a Row gives the inner Expanded an unbounded width,
//     causing "RenderFlex children have non-zero flex but incoming width
//     constraints are unbounded."

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/design_system/widgets/molecules/ds_secure_view.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/shared/helpers/contact_launch_uri.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DeliverySectionHeader', () {
    testWidgets('renders in a Column without errors', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(children: [DeliverySectionHeader(label: 'Section Label')]),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('SECTION LABEL'), findsOneWidget);
    });

    testWidgets(
      'renders inside Row when wrapped in Expanded — no unbounded-width error',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Row(
              children: [
                // Rule: always wrap in Expanded when used inside a Row.
                Expanded(
                  child: DeliverySectionHeader(label: 'Search Results (3)'),
                ),
                TextButton(onPressed: () {}, child: const Text('Add All')),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('SEARCH RESULTS (3)'), findsOneWidget);
      },
    );

    testWidgets(
      'bare in Row (without Expanded) throws unbounded-width FlutterError — '
      'confirms the rule is load-bearing',
      (tester) async {
        // This test documents the failure mode so future refactors know the
        // exact symptom they are guarding against.
        final errors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = errors.add;

        await tester.pumpWidget(
          _wrap(
            Row(
              children: [
                // ← bare, no Expanded wrapper — intentionally wrong
                DeliverySectionHeader(label: 'Bare Header'),
                const SizedBox(width: 80),
              ],
            ),
          ),
        );

        FlutterError.onError = originalOnError;

        final hasUnboundedError = errors.any(
          (e) =>
              e.toString().contains('unbounded') ||
              e.toString().contains('non-zero flex'),
        );
        expect(
          hasUnboundedError,
          isTrue,
          reason:
              'DeliverySectionHeader must not be placed bare inside a Row; '
              'wrap it in Expanded.',
        );
      },
    );
  });

  group('delivery account contact message', () {
    const barcode = 'FSIEE586361';

    test('recipient contact uses recipient name in message', () {
      final greeting = resolveContactGreetingName(
        targetName: 'ROMEO CRIZALDO LANUZA',
        recipientName: 'ROMEO CRIZALDO LANUZA',
      );
      final message = buildDeliveryContactMessage(
        recipientName: greeting,
        barcode: barcode,
      );

      expect(message, contains('Hi ROMEO CRIZALDO LANUZA,'));
      expect(message, contains('FSIEE586361'));
    });

    test('auth rep contact uses auth rep name in message', () {
      final greeting = resolveContactGreetingName(
        targetName: 'MA ELIZA CRIZALDO LANUZA',
        recipientName: 'ROMEO CRIZALDO LANUZA',
      );
      final message = buildDeliveryContactMessage(
        recipientName: greeting,
        barcode: barcode,
      );

      expect(message, contains('Hi MA ELIZA CRIZALDO LANUZA,'));
      expect(message, isNot(contains('Hi ROMEO CRIZALDO LANUZA,')));
    });

    testWidgets('account details sheet separates multiple recipient numbers', (
      tester,
    ) async {
      SecureViewManager.setDeveloperModeOverride(true);
      addTearDown(() => SecureViewManager.setDeveloperModeOverride(false));
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const delivery = {
        'recipient_name': 'ROMEO CRIZALDO LANUZA',
        'recipient_address': 'BLK 10 LOT 5 GRANDSTRIKEVILLE 4',
        'contact': '+639609206186 +639123456789',
      };

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showDeliveryAccountDetails(context, delivery, barcode),
              child: const Text('Details'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('RECIPIENT NUMBER'), findsOneWidget);
      expect(find.text('+63 960 920 6186'), findsOneWidget);
      expect(find.text('+63 912 345 6789'), findsOneWidget);
    });

    testWidgets('account details sheet separates multiple auth rep numbers', (
      tester,
    ) async {
      SecureViewManager.setDeveloperModeOverride(true);
      addTearDown(() => SecureViewManager.setDeveloperModeOverride(false));
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const delivery = {
        'recipient_name': 'ROMEO CRIZALDO LANUZA',
        'contact': '+639609206186',
        'authorized_rep': 'MA ELIZA CRIZALDO LANUZA',
        'contact_rep': '+639355349832 +639177788899',
      };

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showDeliveryAccountDetails(context, delivery, barcode),
              child: const Text('Details'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('AUTH REP CONTACT'), findsOneWidget);
      expect(find.text('+63 935 534 9832'), findsOneWidget);
      expect(find.text('+63 917 778 8899'), findsOneWidget);
    });

    testWidgets(
      'account details sheet is blocked for every locked delivery state',
      (tester) async {
        SecureViewManager.setDeveloperModeOverride(true);
        addTearDown(() => SecureViewManager.setDeveloperModeOverride(false));
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const secretName = 'LOCKED RECIPIENT';
        final lockedDeliveries = <String, Map<String, dynamic>>{
          'DELIVERED': {
            'delivery_status': 'DELIVERED',
            'recipient_name': secretName,
            'contact': '+639171234567',
          },
          'MISROUTED': {
            'delivery_status': 'MISROUTED',
            'recipient_name': secretName,
            'contact': '+639171234567',
          },
          'For Return': {
            'delivery_status': 'FAILED_DELIVERY',
            'delivery_attempts': 3,
            'recipient_name': secretName,
            'contact': '+639171234567',
          },
          'verified_with_pay': {
            'delivery_status': 'FAILED_DELIVERY',
            'delivery_attempts': 1,
            'rts_verification_status': 'verified_with_pay',
            'recipient_name': secretName,
            'contact': '+639171234567',
          },
          'dirty sync': {
            'delivery_status': 'FOR_DELIVERY',
            '_sync_status': 'dirty',
            'recipient_name': secretName,
            'contact': '+639171234567',
          },
        };

        for (final entry in lockedDeliveries.entries) {
          await tester.pumpWidget(
            _wrap(
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      showDeliveryAccountDetails(context, entry.value, barcode),
                  child: Text('Open ${entry.key}'),
                ),
              ),
            ),
          );

          await tester.tap(find.text('Open ${entry.key}'));
          await tester.pumpAndSettle();

          expect(find.text('ACCOUNT DETAILS'), findsNothing, reason: entry.key);
          expect(find.text(secretName), findsNothing, reason: entry.key);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
    );

    testWidgets('account details sheet shows recipient and auth rep numbers', (
      tester,
    ) async {
      SecureViewManager.setDeveloperModeOverride(true);
      addTearDown(() => SecureViewManager.setDeveloperModeOverride(false));
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final delivery = {
        'recipient_name': 'ROMEO CRIZALDO LANUZA',
        'recipient_address': 'BLK 10 LOT 5 GRANDSTRIKEVILLE 4',
        'contact': '+639609206186',
        'authorized_rep': 'MA ELIZA CRIZALDO LANUZA',
        'contact_rep': '+639355349832',
      };

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showDeliveryAccountDetails(context, delivery, barcode),
              child: const Text('Details'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('ACCOUNT DETAILS'), findsOneWidget);
      expect(find.text('+63 960 920 6186'), findsOneWidget);
      expect(find.text('+63 935 534 9832'), findsOneWidget);
      expect(find.text('ROMEO CRIZALDO LANUZA'), findsOneWidget);
      expect(find.text('MA ELIZA CRIZALDO LANUZA'), findsOneWidget);
    });
  });
}
