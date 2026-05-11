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
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';

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
}
