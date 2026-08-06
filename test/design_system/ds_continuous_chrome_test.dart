// Continuous header chrome — anti-black regression suite.
//
// Screens: delivery update, failed-delivery filters, bagsakan form.
// Pattern: AppHeaderBar(showBottomBorder: false) + DsIntegratedSubHeader.
//
// NEVER regress to:
//   - transparent AppBar + forceMaterialTransparency on continuous headers
//   - transparent statusBarColor (Android window shows pure black)
//   - Theme/seed primary instead of DSColors.primary for selected glyphs
//
// See docs/design-system.md § Continuous chrome (header extension).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/ds_segmented_selector.dart';

void main() {
  const fsiGreen = Color(0xFF307539);

  bool isBlackish(Color? c) {
    if (c == null) return false;
    if (c == DSColors.black ||
        c == const Color(0xFF000000) ||
        c == Colors.black) {
      return true;
    }
    return c.a > 0.9 && c.r < 0.08 && c.g < 0.08 && c.b < 0.08;
  }

  /// Continuous screen skeleton matching production pattern.
  /// [leading] avoids [GoRouter.canPop] (no router in unit tests).
  Future<void> pumpContinuousScreen(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DSTheme.build(brightness),
          home: Builder(
            builder: (context) {
              return DsAppScaffold(
                appBar: const AppHeaderBar(
                  title: 'Failed Deliveries',
                  showBottomBorder: false,
                  showNotificationBell: false,
                  // Avoid GoRouter.canPop in tests.
                  leading: SizedBox.shrink(),
                ),
                body: Column(
                  children: [
                    DsIntegratedSubHeader(
                      child: DsIntegratedSubHeader.segment<String>(
                        context: context,
                        selected: 'redelivery',
                        onChanged: (_) {},
                        options: const [
                          DSSegmentOption(
                            value: 'redelivery',
                            label: 'For Redelivery',
                            icon: Icons.local_shipping_rounded,
                            color: DSColors.white,
                            badge: 2,
                          ),
                          DSSegmentOption(
                            value: 'rts',
                            label: 'For Return',
                            icon: Icons.assignment_return_rounded,
                            color: DSColors.white,
                            badge: 2,
                          ),
                        ],
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    // Drain flutter_animate fade timers on AppHeaderBar (dFast).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('DsShellSystemUi — never black / never transparent status bar', () {
    testWidgets('shell light: statusBarColor is exact FSI primary', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.light),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      final s = DsShellSystemUi.shell(tester.element(find.byType(Scaffold)));
      expect(s.statusBarColor, fsiGreen);
      expect(s.statusBarColor, DSColors.primary);
      expect(isBlackish(s.statusBarColor), isFalse);
      expect(s.statusBarColor, isNot(DSColors.transparent));
      expect(s.systemNavigationBarColor, DSColors.primary);
      expect(isBlackish(s.systemNavigationBarColor), isFalse);
      expect(s.statusBarIconBrightness, Brightness.light);
    });

    testWidgets('shell dark: statusBarColor is primaryDark not black', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.dark),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      final s = DsShellSystemUi.shell(tester.element(find.byType(Scaffold)));
      expect(s.statusBarColor, DSColors.primaryDark);
      expect(isBlackish(s.statusBarColor), isFalse);
      expect(s.systemNavigationBarColor, DSColors.primaryDark);
    });

    test('cold-start fallback status bar is primary not black/transparent', () {
      final s = DsShellSystemUi.shellStyleLightFallback;
      expect(s.statusBarColor, DSColors.primary);
      expect(s.statusBarColor, isNot(DSColors.transparent));
      expect(isBlackish(s.statusBarColor), isFalse);
      expect(s.systemNavigationBarColor, DSColors.primary);
    });
  });

  group('AppHeaderBar continuous — solid brand (anti-black)', () {
    testWidgets(
      'continuous: AppBar background is solid primary, not transparent',
      (tester) async {
        await pumpContinuousScreen(tester);
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, fsiGreen);
        expect(appBar.backgroundColor, DSColors.primary);
        expect(appBar.backgroundColor, isNot(DSColors.transparent));
        expect(isBlackish(appBar.backgroundColor), isFalse);
      },
    );

    testWidgets(
      'continuous: forceMaterialTransparency is false (no black window)',
      (tester) async {
        await pumpContinuousScreen(tester);
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.forceMaterialTransparency, isFalse);
      },
    );

    testWidgets(
      'brand AppHeaderBar: no DSGlassChrome (solid paint — no dark corner frost)',
      (tester) async {
        await pumpContinuousScreen(tester);
        expect(find.byType(DSGlassChrome), findsNothing);
      },
    );

    testWidgets(
      'standalone brand header: solid primary, square bottom (no radius)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: DSTheme.build(Brightness.light),
              home: const DsAppScaffold(
                appBar: AppHeaderBar(
                  title: 'Dispatch',
                  showBottomBorder: true,
                  showNotificationBell: false,
                  leading: SizedBox.shrink(),
                ),
                body: SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, DSColors.primary);
        expect(appBar.backgroundColor, isNot(DSColors.transparent));
        expect(appBar.forceMaterialTransparency, isFalse);
        expect(appBar.shadowColor, DSColors.transparent);
        expect(appBar.elevation, 0);
        expect(appBar.shape, isNull);
        expect(find.byType(DSGlassChrome), findsNothing);
      },
    );

    testWidgets(
      'continuous: systemOverlayStyle statusBarColor is solid brand',
      (tester) async {
        await pumpContinuousScreen(tester);
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        final style = appBar.systemOverlayStyle!;
        expect(style.statusBarColor, DSColors.primary);
        expect(style.statusBarColor, isNot(DSColors.transparent));
        expect(isBlackish(style.statusBarColor), isFalse);
        expect(style.statusBarIconBrightness, Brightness.light);
      },
    );

    testWidgets('continuous dark: solid primaryDark not black', (tester) async {
      await pumpContinuousScreen(tester, brightness: Brightness.dark);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, DSColors.primaryDark);
      expect(isBlackish(appBar.backgroundColor), isFalse);
      expect(appBar.forceMaterialTransparency, isFalse);
      final style = appBar.systemOverlayStyle!;
      expect(style.statusBarColor, DSColors.primaryDark);
      expect(isBlackish(style.statusBarColor), isFalse);
    });
  });

  group('DsIntegratedSubHeader — solid brand extension', () {
    testWidgets('strip paints exact DSColors.primary (not black, not glass)', (
      tester,
    ) async {
      await pumpContinuousScreen(tester);

      final brandBoxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where((w) {
            final d = w.decoration;
            return d is BoxDecoration && d.color == DSColors.primary;
          });
      expect(brandBoxes, isNotEmpty);

      for (final w in brandBoxes) {
        final c = (w.decoration as BoxDecoration).color;
        expect(isBlackish(c), isFalse);
        expect(c, isNot(DSColors.transparent));
      }
      expect(find.byType(DSGlassChrome), findsNothing);
    });

    testWidgets('segment selected color is exact FSI primary not seed', (
      tester,
    ) async {
      await pumpContinuousScreen(tester);
      final seg = tester.widget<DSSegmentedSelector<String>>(
        find.byType(DSSegmentedSelector<String>),
      );
      expect(seg.selectedTextColor, fsiGreen);
      expect(seg.selectedTextColor, DSColors.primary);
      expect(seg.height, 48);
      expect(seg.layout, DSSegmentLayout.horizontal);
      expect(seg.pillInset, 4);
      expect(isBlackish(seg.selectedTextColor), isFalse);
      expect(isBlackish(seg.backgroundColor), isFalse);
    });
  });

  group('Production continuous screens contract', () {
    /// Keep in sync with: rg "showBottomBorder:\\s*false" lib/features
    test('known continuous chrome call sites', () {
      const continuousScreens = <String>[
        'lib/features/delivery/delivery_update_screen.dart',
        'lib/features/delivery/delivery_status_list_screen.dart', // FD only
        'lib/features/bagsakan/bagsakan_form_screen.dart',
      ];
      expect(continuousScreens, hasLength(3));
      for (final path in continuousScreens) {
        expect(path.startsWith('lib/features/'), isTrue);
      }
    });
  });

  group('Header bottom edge — no dark corner spots', () {
    testWidgets('headerShadow has no black channel (rounded corners stay clean)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.light),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      final ctx = tester.element(find.byType(Scaffold));
      final shadows = DSGlass.headerShadow(ctx);
      expect(shadows, isNotEmpty);
      for (final s in shadows) {
        // Black under the curve = dirty spots on Dispatch / list headers.
        expect(s.color.r + s.color.g + s.color.b, greaterThan(0.15));
        expect(s.color, isNot(DSColors.black));
        expect(s.color, isNot(const Color(0xFF000000)));
        // Prefer brand-green ambient.
        expect(s.color.g, greaterThan(s.color.r));
      }
    });

    testWidgets('headerShadow dark mode still avoids pure black', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.dark),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      final ctx = tester.element(find.byType(Scaffold));
      for (final s in DSGlass.headerShadow(ctx)) {
        expect(s.color, isNot(DSColors.black));
        expect(s.color.a, lessThan(0.5));
      }
    });
  });
}
