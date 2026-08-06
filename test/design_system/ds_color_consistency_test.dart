import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Color-sensitive consistency: green glass chrome, theme surfaces, brand tokens.
void main() {
  group('Brand tokens (stable)', () {
    test('primary and gold are fixed brand hexes', () {
      expect(DSColors.primary, const Color(0xFF307539));
      expect(DSColors.primaryDark, const Color(0xFF3D8A47));
      expect(DSColors.gold, const Color(0xFFCC9853));
      expect(DSColors.scaffoldLight, const Color(0xFFFFFFFF));
      expect(DSColors.scaffoldDark, const Color(0xFF111111));
    });

    test('shell preset keeps brand orbs visible (not pure black void)', () {
      expect(DsBrandBackdropConfig.shell.orbAlphaScale, greaterThan(0.5));
      expect(DsBrandBackdropConfig.shell.showOrbs, isTrue);
      expect(DsBrandBackdropConfig.shell.variant, DsBackdrop.shell);
    });
  });

  group('DSGlass chrome (green glass)', () {
    Future<void> pumpTheme(WidgetTester tester, Brightness b) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(b),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
    }

    testWidgets('light chrome fill is primary green family', (tester) async {
      await pumpTheme(tester, Brightness.light);
      final ctx = tester.element(find.byType(Scaffold));
      final fill = DSGlass.fill(ctx, tone: DSGlassTone.chrome);
      expect(fill.r, closeTo(DSColors.primary.r, 0.02));
      expect(fill.g, closeTo(DSColors.primary.g, 0.02));
      expect(fill.b, closeTo(DSColors.primary.b, 0.02));
      expect(fill.a, closeTo(DSGlass.chromeAlphaLight, 0.02));
    });

    testWidgets('dark chrome fill is primaryDark family', (tester) async {
      await pumpTheme(tester, Brightness.dark);
      final ctx = tester.element(find.byType(Scaffold));
      final fill = DSGlass.fill(ctx, tone: DSGlassTone.chrome);
      expect(fill.r, closeTo(DSColors.primaryDark.r, 0.02));
      expect(fill.g, closeTo(DSColors.primaryDark.g, 0.02));
      expect(fill.b, closeTo(DSColors.primaryDark.b, 0.02));
      expect(fill.a, closeTo(DSGlass.chromeAlphaDark, 0.02));
    });

    testWidgets('onChrome glyphs are white (readable on green glass)', (
      tester,
    ) async {
      await pumpTheme(tester, Brightness.light);
      final ctx = tester.element(find.byType(Scaffold));
      expect(DSGlass.onChrome(ctx), DSColors.white);
      await pumpTheme(tester, Brightness.dark);
      final ctxDark = tester.element(find.byType(Scaffold));
      expect(DSGlass.onChrome(ctxDark), DSColors.white);
    });
  });

  group('DsShellSystemUi adapts to green glass', () {
    Future<BuildContext> ctx(WidgetTester tester, Brightness b) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(b),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      return tester.element(find.byType(Scaffold));
    }

    testWidgets('shell: light icons on green status/nav (light theme)', (
      tester,
    ) async {
      final c = await ctx(tester, Brightness.light);
      final s = DsShellSystemUi.shell(c);
      expect(s.statusBarIconBrightness, Brightness.light);
      expect(s.systemNavigationBarIconBrightness, Brightness.light);
      // Solid brand status bar — transparent shows Android black window.
      expect(s.statusBarColor, DSColors.primary);
      expect(s.statusBarColor, isNot(DSColors.transparent));
      expect(s.statusBarColor, isNot(DSColors.black));
      expect(s.systemNavigationBarColor, DSColors.primary);
      expect(s.systemNavigationBarContrastEnforced, isFalse);
      expect(s.systemStatusBarContrastEnforced, isFalse);
    });

    testWidgets('shell: light icons on green status/nav (dark theme)', (
      tester,
    ) async {
      final c = await ctx(tester, Brightness.dark);
      final s = DsShellSystemUi.shell(c);
      expect(s.statusBarIconBrightness, Brightness.light);
      expect(s.systemNavigationBarIconBrightness, Brightness.light);
      expect(s.statusBarColor, DSColors.primaryDark);
      expect(s.statusBarColor, isNot(DSColors.black));
      expect(s.systemNavigationBarColor, DSColors.primaryDark);
    });

    testWidgets('surfaceFor light: dark icons on white scaffold', (
      tester,
    ) async {
      final c = await ctx(tester, Brightness.light);
      final s = DsShellSystemUi.surfaceFor(c);
      expect(s.statusBarIconBrightness, Brightness.dark);
      expect(s.systemNavigationBarColor, DSColors.scaffoldLight);
      expect(s.systemNavigationBarIconBrightness, Brightness.dark);
    });

    testWidgets('surfaceFor dark: light icons on dark scaffold', (
      tester,
    ) async {
      final c = await ctx(tester, Brightness.dark);
      final s = DsShellSystemUi.surfaceFor(c);
      expect(s.statusBarIconBrightness, Brightness.light);
      expect(s.systemNavigationBarColor, DSColors.scaffoldDark);
      expect(s.systemNavigationBarIconBrightness, Brightness.light);
    });

    testWidgets('styleFor defaults to shell (green glass)', (tester) async {
      final c = await ctx(tester, Brightness.light);
      final s = DsShellSystemUi.styleFor(c);
      expect(s.systemNavigationBarColor, DSColors.primary);
      expect(s.statusBarIconBrightness, Brightness.light);
    });

    test('cold-start fallback matches green glass (not black)', () {
      final s = DsShellSystemUi.shellStyleLightFallback;
      expect(s.systemNavigationBarColor, DSColors.primary);
      expect(s.statusBarColor, DSColors.primary);
      expect(s.statusBarColor, isNot(DSColors.transparent));
      expect(s.statusBarIconBrightness, Brightness.light);
      expect(s.systemNavigationBarColor, isNot(DSColors.black));
      expect(s.systemNavigationBarColor, isNot(const Color(0xFF000000)));
      expect(s.statusBarColor, isNot(DSColors.black));
    });
  });

  group('Theme filled buttons (disabled readable)', () {
    testWidgets('light filled disabled is soft primary not black', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.light),
          home: Scaffold(
            body: FilledButton(onPressed: null, child: const Text('GO')),
          ),
        ),
      );
      final style = Theme.of(
        tester.element(find.byType(FilledButton)),
      ).filledButtonTheme.style!;
      final bg = style.backgroundColor?.resolve({WidgetState.disabled});
      final fg = style.foregroundColor?.resolve({WidgetState.disabled});
      expect(bg, isNotNull);
      expect(fg, isNotNull);
      // Soft primary tint — not pure black.
      expect(bg!.a, lessThan(1.0));
      expect(bg.r + bg.g + bg.b, greaterThan(0.05));
      expect(fg!.a, greaterThan(0.5));
    });
  });

  group('DsBottomActionBar surfaces', () {
    testWidgets('light dock is cardLight not black', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.light),
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: DsBottomActionBar(
              child: FilledButton(onPressed: () {}, child: const Text('OK')),
            ),
          ),
        ),
      );
      final m = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(DsBottomActionBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(m.color, DSColors.cardLight);
    });

    testWidgets('dark dock is cardElevatedDark not pure black', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.dark),
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: DsBottomActionBar(
              child: FilledButton(onPressed: null, child: const Text('OK')),
            ),
          ),
        ),
      );
      final m = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(DsBottomActionBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(m.color, DSColors.cardElevatedDark);
      expect(m.color, isNot(DSColors.black));
    });
  });

  group('DsAppScaffold shell region', () {
    testWidgets('wraps with green-glass system UI', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.light),
          home: DsAppScaffold(body: const Center(child: Text('X'))),
        ),
      );
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.systemNavigationBarColor, DSColors.primary);
      expect(find.byType(DsBrandBackdrop), findsOneWidget);
    });
  });
}
