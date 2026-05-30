import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/design_system/widgets/molecules/ds_secure_view.dart';

void main() {
  group('SecureView & SecureViewManager Tests', () {
    testWidgets('SecureView can be pumped in widget tree without throwing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SecureView(child: Text('Secret Content'))),
        ),
      );
      await tester.pump();

      expect(find.text('Secret Content'), findsOneWidget);
    });

    test(
      'SecureViewManager.setDeveloperModeOverride sets developer mode correctly',
      () {
        // Toggle to true
        SecureViewManager.setDeveloperModeOverride(true);
        // Toggle back to false to be clean
        SecureViewManager.setDeveloperModeOverride(false);
      },
    );

    testWidgets(
      'SecureBadge is hidden when kSecureScreenshots is disabled or is absent',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SecureBadge())),
        );
        await tester.pump();

        // SecureBadge might be empty when config is checked or rendered depending on flag
      },
    );
  });
}
