// DOCS: docs/development-standards.md
// DOCS: docs/core/services.md — update that file when you edit this one.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/services/runtime_environment_service.dart';
import 'package:fsi_courier_app/core/services/app_version_service.dart';
import 'package:fsi_courier_app/models/update_info.dart';

/// Remote manifest URL — derived from the app's configured API base URL.
/// The backend serves `GET /api/mbl/mobile-version.json` alongside other
/// mobile endpoints (see docs/itms-api/mobile-api-requirements.md).
String get _kVersionManifestUrl {
  final runtimeBaseUrl = RuntimeEnvironmentService.instance.activeApiBaseUrl;
  final base = runtimeBaseUrl.endsWith('/')
      ? runtimeBaseUrl
      : '$runtimeBaseUrl/';
  return '${base}mobile-version.json';
}

/// App Store URL used on iOS (direct APK sideloading is not allowed on iOS).
const _kIosAppStoreUrl = 'https://apps.apple.com/app/idYOUR_APP_ID';

/// Handles update-lifecycle operations: version checks and directing the
/// user to the app store listing for the current platform.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  final Dio _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 10)),
  );

  // ── Version check ──────────────────────────────────────────────────────────

  /// Fetches [_kVersionManifestUrl], compares versions, and returns an
  /// [UpdateInfo] when an update is available or `null` when the app is
  /// already up to date.  Silently returns `null` on any network error so
  /// the app continues to work offline.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _kVersionManifestUrl,
        options: Options(responseType: ResponseType.json),
      );

      final json = response.data;
      if (json == null) return null;

      final currentVersion = AppVersionService.version;
      final latestVersion = (json['latest_version'] as String? ?? '').trim();

      if (latestVersion.isEmpty) return null;
      if (!UpdateInfo.isNewerVersion(latestVersion, currentVersion)) {
        return null; // already up to date
      }

      return UpdateInfo.fromJson(json, currentVersion: currentVersion);
    } catch (e) {
      debugPrint('[UpdateService] checkForUpdate silently failed: $e');
      return null;
    }
  }

  // ── Store listing ──────────────────────────────────────────────────────────

  /// Opens the platform app store listing for this app.
  ///
  /// iOS always opens the App Store URL. Android opens the Play Store
  /// listing when [kIsPlayStoreDistribution] is true; otherwise this is a
  /// no-op (there is no other update mechanism shipped in this build — see
  /// docs/core/update-system.md).
  ///
  /// Returns `true` if a launch was attempted and succeeded.
  Future<bool> launchStoreListing() async {
    final Uri? uri;
    if (Platform.isIOS) {
      uri = Uri.parse(_kIosAppStoreUrl);
    } else if (kIsPlayStoreDistribution) {
      uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=${AppVersionService.packageName}',
      );
    } else {
      uri = null;
    }

    if (uri == null) return false;
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Mandatory check ────────────────────────────────────────────────────────

  /// Returns `true` when the running version is below [minimumVersion].
  bool isMandatoryUpdate(String minimumVersion) {
    final current = AppVersionService.version;
    return UpdateInfo.isNewerVersion(minimumVersion, current);
  }
}
