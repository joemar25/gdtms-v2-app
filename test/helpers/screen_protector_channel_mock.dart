import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prevents [ScreenProtector] platform calls from hanging unit/widget tests.
///
/// Without a handler, `MethodChannel('screen_protector')` never completes
/// under [TestWidgetsFlutterBinding], which freezes any test that awaits
/// [SecureViewManager.setDeveloperModeOverride] or mounts [SecureView].
void mockScreenProtectorChannel() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('screen_protector'), (
        MethodCall call,
      ) async {
        // All screen_protector methods are fire-and-forget for tests.
        return null;
      });
}

void clearScreenProtectorChannelMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('screen_protector'), null);
}
