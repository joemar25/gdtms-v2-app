import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/ds_segmented_selector.dart';

void main() {
  testWidgets(
    'DsIntegratedSubHeader sizes to tall child without RenderFlex overflow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DsIntegratedSubHeader(
                  padding: const EdgeInsets.fromLTRB(
                    DSSpacing.md,
                    DSSpacing.xs,
                    DSSpacing.md,
                    DSSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 80, color: Colors.white24),
                      const SizedBox(height: 8),
                      const Text('tap or swipe to change status'),
                    ],
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final subHeader = tester.getSize(find.byType(DsIntegratedSubHeader));
      expect(subHeader.height, greaterThan(DSGlass.chromeHeight));
      expect(subHeader.height, greaterThanOrEqualTo(80 + 8 + 4 + 16));
    },
  );

  testWidgets(
    'DsIntegratedSubHeader paints exact solid brand primary (header extension)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.light),
          home: const Scaffold(
            body: DsIntegratedSubHeader(
              child: SizedBox(height: 48, width: 200),
            ),
          ),
        ),
      );

      // Solid brand only — no second glass chrome that drifts color.
      expect(find.byType(DSGlassChrome), findsNothing);
      final decorated = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .firstWhere((w) {
            final d = w.decoration;
            return d is BoxDecoration && d.color == DSColors.primary;
          });
      final box = decorated.decoration as BoxDecoration;
      expect(box.color, const Color(0xFF307539));
      final radius = box.borderRadius! as BorderRadius;
      expect(radius.topLeft, Radius.zero);
      expect(radius.bottomLeft, Radius.circular(DSStyles.radiusXL));
    },
  );

  testWidgets('chrome segment: h=48 horizontal, exact FSI primary selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DSTheme.build(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return DsIntegratedSubHeader.segment<String>(
                context: context,
                selected: 'a',
                onChanged: (_) {},
                options: const [
                  DSSegmentOption(
                    value: 'a',
                    label: 'For Redelivery',
                    icon: Icons.local_shipping_rounded,
                    color: DSColors.white,
                  ),
                  DSSegmentOption(
                    value: 'b',
                    label: 'For Return',
                    icon: Icons.assignment_return_rounded,
                    color: DSColors.white,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    final seg = tester.widget<DSSegmentedSelector<String>>(
      find.byType(DSSegmentedSelector<String>),
    );
    expect(seg.height, 48);
    expect(seg.layout, DSSegmentLayout.horizontal);
    expect(seg.pillInset, 4);
    // Exact token — not ColorScheme.fromSeed drift.
    expect(seg.selectedTextColor, const Color(0xFF307539));
    expect(seg.selectedTextColor, DSColors.primary);
  });
}
