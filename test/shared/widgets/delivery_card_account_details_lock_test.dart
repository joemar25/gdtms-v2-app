import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/design_system/widgets/molecules/ds_secure_view.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';

/// PII fields used to detect accidental account-detail leaks in widget tests.
const _secretName = 'SECRET RECIPIENT';
const _secretAddress = '123 PRIVATE STREET';
const _secretPhone = '+639171234567';

const _basePii = {
  'barcode': 'FSIEE999001',
  'recipient_name': _secretName,
  'recipient_address': _secretAddress,
  'contact': _secretPhone,
  'product': 'ELITE',
};

void _configureLargeScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required Map<String, dynamic> delivery,
  bool compact = false,
  bool enableHoldToReveal = true,
  bool isChecking = false,
}) async {
  SecureViewManager.setDeveloperModeOverride(true);
  addTearDown(() => SecureViewManager.setDeveloperModeOverride(false));
  _configureLargeScreen(tester);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeliveryCard(
          delivery: delivery,
          onTap: () {},
          compact: compact,
          enableHoldToReveal: enableHoldToReveal,
          isChecking: isChecking,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _expectNoAccountDetailsLeak(
  WidgetTester tester, {
  required String reason,
}) async {
  expect(find.text('ACCOUNT DETAILS'), findsNothing, reason: reason);
  expect(find.text(_secretName), findsNothing, reason: reason);
  expect(find.text(_secretPhone), findsNothing, reason: reason);
}

void main() {
  group('DeliveryCard account-details lock (edge cases)', () {
    final lockedCases = <String, Map<String, dynamic>>{
      'DELIVERED': {
        ..._basePii,
        'delivery_status': 'DELIVERED',
        '_delivered_at': DateTime.now().millisecondsSinceEpoch,
      },
      'delivered lowercase': {..._basePii, 'delivery_status': 'delivered'},
      'MISROUTED': {
        ..._basePii,
        'delivery_status': 'MISROUTED',
        '_completed_at': DateTime.now().millisecondsSinceEpoch,
      },
      'misrouted lowercase': {..._basePii, 'delivery_status': 'misrouted'},
      'For Return — delivery_attempts = 3': {
        ..._basePii,
        'delivery_status': 'FAILED_DELIVERY',
        'delivery_attempts': 3,
      },
      'For Return — delivery_attempts = 4': {
        ..._basePii,
        'delivery_status': 'FAILED_DELIVERY',
        'delivery_attempts': 4,
      },
      'For Return — delivery_attempts string "3"': {
        ..._basePii,
        'delivery_status': 'FAILED_DELIVERY',
        'delivery_attempts': '3',
      },
      'For Return — failed_delivery_count fallback': {
        ..._basePii,
        'delivery_status': 'FAILED_DELIVERY',
        'failed_delivery_count': 3,
      },
      'verified_with_pay (1 attempt)': {
        ..._basePii,
        'delivery_status': 'FAILED_DELIVERY',
        'delivery_attempts': 1,
        'rts_verification_status': 'verified_with_pay',
      },
      'verified_no_pay (2 attempts)': {
        ..._basePii,
        'delivery_status': 'FAILED_DELIVERY',
        'delivery_attempts': 2,
        'rts_verification_status': 'verified_no_pay',
      },
      'legacy RTS at 3 attempts': {
        ..._basePii,
        'delivery_status': 'RTS',
        'delivery_attempts': 3,
      },
      'dirty sync on actionable status': {
        ..._basePii,
        'delivery_status': 'FOR_DELIVERY',
        '_sync_status': 'dirty',
      },
      'prefixed verification field': {
        ..._basePii,
        'delivery_status': 'FAILED_DELIVERY',
        'delivery_attempts': 1,
        '_rts_verification_status': 'verified_with_pay',
      },
    };

    for (final entry in lockedCases.entries) {
      testWidgets('locked [$entry.key] hides info icon', (tester) async {
        await _pumpCard(tester, delivery: entry.value);
        expect(
          find.byIcon(Icons.info_outline_rounded),
          findsNothing,
          reason: entry.key,
        );
      });

      testWidgets('locked [$entry.key] hides recipient name on card', (
        tester,
      ) async {
        await _pumpCard(tester, delivery: entry.value);
        expect(find.text(_secretName), findsNothing, reason: entry.key);
      });

      testWidgets('locked [$entry.key] blocks long-press account details', (
        tester,
      ) async {
        await _pumpCard(tester, delivery: entry.value);
        await tester.longPress(find.byType(DeliveryCard));
        await tester.pumpAndSettle();
        await _expectNoAccountDetailsLeak(tester, reason: entry.key);
      });

      testWidgets(
        'locked [$entry.key] blocks direct showDeliveryAccountDetails call',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showDeliveryAccountDetails(
                      context,
                      entry.value,
                      entry.value['barcode']!.toString(),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          SecureViewManager.setDeveloperModeOverride(true);
          addTearDown(() => SecureViewManager.setDeveloperModeOverride(false));
          _configureLargeScreen(tester);

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await _expectNoAccountDetailsLeak(tester, reason: entry.key);
        },
      );
    }

    final unlockedCases = <String, Map<String, dynamic>>{
      'FOR_DELIVERY': {..._basePii, 'delivery_status': 'FOR_DELIVERY'},
      'PENDING legacy alias': {..._basePii, 'delivery_status': 'PENDING'},
      'For Redelivery — 1 attempt': {
        ..._basePii,
        'delivery_status': 'FAILED_DELIVERY',
        'delivery_attempts': 1,
        'rts_verification_status': 'unvalidated',
      },
      'For Redelivery — 2 attempts': {
        ..._basePii,
        'delivery_status': 'FAILED_DELIVERY',
        'delivery_attempts': 2,
      },
      'For Redelivery — failed_delivery_count only': {
        ..._basePii,
        'delivery_status': 'FAILED_DELIVERY',
        'failed_delivery_count': 2,
      },
      'bagsakan group — actionable FOR_DELIVERY': {
        ..._basePii,
        'delivery_status': 'FOR_DELIVERY',
        'bagsakan_id': 42,
      },
    };

    for (final entry in unlockedCases.entries) {
      testWidgets('unlocked [$entry.key] shows info icon', (tester) async {
        await _pumpCard(tester, delivery: entry.value);
        expect(
          find.byIcon(Icons.info_outline_rounded),
          findsOneWidget,
          reason: entry.key,
        );
      });

      testWidgets('unlocked [$entry.key] reveals details via info tap', (
        tester,
      ) async {
        await _pumpCard(tester, delivery: entry.value);
        await tester.tap(find.byIcon(Icons.info_outline_rounded));
        await tester.pumpAndSettle();

        expect(find.text('ACCOUNT DETAILS'), findsOneWidget, reason: entry.key);
        expect(find.text(_secretName), findsWidgets, reason: entry.key);
      });

      testWidgets('unlocked [$entry.key] reveals details via long-press', (
        tester,
      ) async {
        await _pumpCard(tester, delivery: entry.value);
        await tester.longPress(find.byType(DeliveryCard));
        await tester.pumpAndSettle();

        expect(find.text('ACCOUNT DETAILS'), findsOneWidget, reason: entry.key);
        expect(find.text(_secretName), findsWidgets, reason: entry.key);
      });
    }

    testWidgets(
      'enableHoldToReveal=false blocks long-press even when unlocked',
      (tester) async {
        await _pumpCard(
          tester,
          delivery: {..._basePii, 'delivery_status': 'FOR_DELIVERY'},
          enableHoldToReveal: false,
        );

        expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
        await tester.longPress(find.byType(DeliveryCard));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('ACCOUNT DETAILS'), findsNothing);
      },
    );

    testWidgets('isChecking blocks info icon and long-press', (tester) async {
      await _pumpCard(
        tester,
        delivery: {..._basePii, 'delivery_status': 'FOR_DELIVERY'},
        isChecking: true,
      );

      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
      await tester.longPress(find.byType(DeliveryCard));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ACCOUNT DETAILS'), findsNothing);
    });

    testWidgets('compact locked card hides recipient name', (tester) async {
      await _pumpCard(
        tester,
        delivery: {..._basePii, 'delivery_status': 'DELIVERED'},
        compact: true,
      );

      expect(find.text(_secretName), findsNothing);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    });

    testWidgets('compact unlocked card shows recipient name', (tester) async {
      await _pumpCard(
        tester,
        delivery: {..._basePii, 'delivery_status': 'FOR_DELIVERY'},
        compact: true,
      );

      expect(find.text(_secretName), findsOneWidget);
    });

    testWidgets(
      'delivery_attempts wins over lower failed_delivery_count for lock at 3',
      (tester) async {
        final delivery = {
          ..._basePii,
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': 3,
          'failed_delivery_count': 1,
        };

        await _pumpCard(tester, delivery: delivery);
        expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
        await tester.longPress(find.byType(DeliveryCard));
        await tester.pumpAndSettle();
        await _expectNoAccountDetailsLeak(
          tester,
          reason: 'delivery_attempts authoritative at 3',
        );
      },
    );

    testWidgets(
      '2 attempts from delivery_attempts stays unlocked despite high failed_delivery_count',
      (tester) async {
        final delivery = {
          ..._basePii,
          'delivery_status': 'FAILED_DELIVERY',
          'delivery_attempts': 2,
          'failed_delivery_count': 5,
        };

        await _pumpCard(tester, delivery: delivery);
        expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      },
    );
  });
}
