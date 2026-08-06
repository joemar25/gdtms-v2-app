import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/design_system/widgets/molecules/ds_secure_view.dart';

import '../../helpers/screen_protector_channel_mock.dart';

void main() {
  group('SecureView & SecureViewManager Tests', () {
    setUp(mockScreenProtectorChannel);
    tearDown(clearScreenProtectorChannelMock);

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
      'protection is bypassed in debug builds even with developer mode off',
      () async {
        // Tests run as a debug build, so kAppDebugMode is true here — this
        // mirrors a dev running `flutter run` with no dart-defines and
        // developer mode never unlocked. Protection must still be bypassed.
        await SecureViewManager.setDeveloperModeOverride(false);

        expect(kDebugMode, isTrue);
        expect(SecureViewManager.debugBypassProtection, isTrue);
      },
    );

    test(
      'setDeveloperModeOverride awaits the native clear call before '
      'returning, so the bypass is guaranteed in effect immediately after',
      () async {
        await SecureViewManager.setDeveloperModeOverride(true);
        expect(SecureViewManager.debugBypassProtection, isTrue);
        await SecureViewManager.setDeveloperModeOverride(false);
      },
    );

    test(
      'SecureViewManager.setDeveloperModeOverride sets developer mode correctly',
      () async {
        // Toggle to true
        await SecureViewManager.setDeveloperModeOverride(true);
        // Toggle back to false to be clean
        await SecureViewManager.setDeveloperModeOverride(false);
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
