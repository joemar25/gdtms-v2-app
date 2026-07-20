import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/models/update_info.dart';

void main() {
  group('UpdateInfo.fromJson', () {
    test('correctly parses update JSON', () {
      final json = {
        "latest_version": "1.0.1",
        "minimum_version": "1.0.0",
        "release_notes": "test",
        "force_update": false,
      };

      final info = UpdateInfo.fromJson(json, currentVersion: '1.0.0');

      expect(info.latestVersion, '1.0.1');
      expect(info.minimumVersion, '1.0.0');
      expect(info.releaseNotes, 'test');
      expect(info.isMandatory, false);
    });

    test('respects force_update flag', () {
      final json = {
        "latest_version": "1.0.1",
        "minimum_version": "1.0.0",
        "release_notes": "test",
        "force_update": true,
      };

      final info = UpdateInfo.fromJson(json, currentVersion: '1.0.0');
      expect(info.isMandatory, true);
    });

    test('isMandatory when current version is below minimum', () {
      final json = {
        "latest_version": "2.0.0",
        "minimum_version": "1.5.0",
        "release_notes": "test",
        "force_update": false,
      };

      final info = UpdateInfo.fromJson(json, currentVersion: '1.4.9');
      expect(info.isMandatory, true);
    });
  });
}
