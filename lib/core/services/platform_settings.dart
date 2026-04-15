// DOCS: docs/time-enforcement.md

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _kChannel = MethodChannel('fsi_courier/storage');

/// Helper to open device settings pages.
class PlatformSettings {
  PlatformSettings._();

  /// Opens the device Date & Time settings where possible.
  ///
  /// - Android: invokes `openDateTimeSettings` on the native MethodChannel.
  ///   The native side tries `Settings.ACTION_DATE_SETTINGS` first, then falls
  ///   back to `Settings.ACTION_SETTINGS` if the manufacturer restricts it.
  /// - iOS: opens app settings (iOS does not support deep-linking to Date & Time).
  static Future<void> openDateTimeSettings() async {
    if (Platform.isAndroid) {
      try {
        await _kChannel.invokeMethod<void>('openDateTimeSettings');
      } catch (e) {
        debugPrint('[SETTINGS] openDateTimeSettings channel call failed: $e');
      }
      return;
    }

    // iOS / other: open the app's own settings page (closest available target).
    try {
      final uri = Uri.parse('app-settings:');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[SETTINGS] app-settings launch failed: $e');
    }
  }
}
