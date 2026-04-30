import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/core/config.dart';

void main() {
  group('SecureBadge', () {
    testWidgets(
      'Given kSecureScreenshots is true, when built, then shows lock icon',
      (WidgetTester tester) async {
        // Note: In tests, kSecureScreenshots value depends on how the test is run.
        // Usually it defaults to true in our config.

        if (kSecureScreenshots) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(appBar: AppBar(actions: const [SecureBadge()])),
            ),
          );

          expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
          expect(find.byType(Tooltip), findsOneWidget);
        } else {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(appBar: AppBar(actions: const [SecureBadge()])),
            ),
          );

          expect(find.byIcon(Icons.lock_rounded), findsNothing);
        }
      },
    );
  });
}
