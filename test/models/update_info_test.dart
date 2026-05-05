import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/models/update_info.dart';

void main() {
  group('UpdateInfo.fromJson', () {
    test('correctly parses Android update JSON', () {
      final json = {
        "latest_version": "1.0.1",
        "minimum_version": "1.0.0",
        "android_download_url": "https://example.com/android.apk",
        "ios_store_url": "https://example.com/ios",
        "release_notes": "test",
        "file_size_mb": 81.1,
        "checksum_sha256": "A0EDD1BF...",
        "force_update": false,
      };

      final info = UpdateInfo.fromJson(json, currentVersion: '1.0.0');

      expect(info.latestVersion, '1.0.1');
      expect(info.minimumVersion, '1.0.0');
      // In tests (non-iOS environment), it should pick android_download_url
      expect(info.downloadUrl, 'https://example.com/android.apk');
      expect(info.isMandatory, false);
    });

    test('respects force_update flag', () {
      final json = {
        "latest_version": "1.0.1",
        "minimum_version": "1.0.0",
        "android_download_url": "https://example.com/android.apk",
        "ios_store_url": null,
        "release_notes": "test",
        "file_size_mb": 10.0,
        "checksum_sha256": "abc",
        "force_update": true,
      };

      final info = UpdateInfo.fromJson(json, currentVersion: '1.0.0');
      expect(info.isMandatory, true);
    });

    test('isMandatory when current version is below minimum', () {
      final json = {
        "latest_version": "2.0.0",
        "minimum_version": "1.5.0",
        "android_download_url": "https://example.com/android.apk",
        "ios_store_url": null,
        "release_notes": "test",
        "file_size_mb": 10.0,
        "checksum_sha256": "abc",
        "force_update": false,
      };

      final info = UpdateInfo.fromJson(json, currentVersion: '1.4.9');
      expect(info.isMandatory, true);
    });
  });
}
