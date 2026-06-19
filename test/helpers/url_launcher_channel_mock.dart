import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prevents [canLaunchUrl] from hitting the platform channel in widget tests.
void mockUrlLauncherChannel({bool canLaunch = false}) {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (
    MethodCall call,
  ) async {
    switch (call.method) {
      case 'canLaunchUrl':
        return canLaunch;
      case 'launchUrl':
        return true;
      default:
        return null;
    }
  });
}

void clearUrlLauncherChannelMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    null,
  );
}