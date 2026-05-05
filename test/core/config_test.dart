import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/core/config.dart';

void main() {
  group('Security & Compliance Logic', () {
    test('kAppDebugMode is true in test environment', () {
      expect(kAppDebugMode, true);
    });
  });
}
