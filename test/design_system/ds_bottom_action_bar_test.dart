import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

void main() {
  group('DsBottomActionBar', () {
    testWidgets('paints elevated solid surface (not transparent void)', (
      tester,
    ) async {
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

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(DsBottomActionBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, DSColors.cardLight);
      expect(material.elevation, greaterThan(0));
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('dark mode uses elevated dark surface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.dark),
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: DsBottomActionBar(
              child: FilledButton(
                onPressed: null,
                child: const Text('CONFIRM'),
              ),
            ),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(DsBottomActionBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, DSColors.cardElevatedDark);
      expect(find.text('CONFIRM'), findsOneWidget);
    });
  });

  group('DsAppScaffold bottom dock', () {
    testWidgets('extends body when bottomNavigationBar is present', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: DSTheme.build(Brightness.light),
          home: DsAppScaffold(
            body: const Center(child: Text('BODY')),
            bottomNavigationBar: DsBottomActionBar(
              child: FilledButton(
                onPressed: null,
                child: const Text('CONFIRM'),
              ),
            ),
          ),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.extendBody, isTrue);
      expect(find.text('BODY'), findsOneWidget);
      expect(find.text('CONFIRM'), findsOneWidget);
      expect(find.byType(DsBrandBackdrop), findsOneWidget);
    });
  });
}
