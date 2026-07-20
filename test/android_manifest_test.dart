import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main Android manifest removes install and media permissions', () {
    final manifestFile = File('android/app/src/main/AndroidManifest.xml');

    expect(manifestFile.existsSync(), isTrue);

    final manifest = manifestFile.readAsStringSync();

    expect(
      manifest,
      isNot(contains('android.permission.REQUEST_INSTALL_PACKAGES')),
    );
    expect(manifest, isNot(contains('android.permission.READ_MEDIA_IMAGES')));
    expect(manifest, isNot(contains('android.permission.READ_MEDIA_VIDEO')));
  });
}
