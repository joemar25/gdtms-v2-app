// DOCS: docs/development-standards.md
// DOCS: docs/core/services.md — update that file when you edit this one.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/services/app_version_service.dart';
import 'package:fsi_courier_app/models/update_info.dart';

/// Remote manifest URL — derived from the app's configured API base URL.
/// The backend serves `GET /api/mbl/mobile-version.json` alongside other
/// mobile endpoints (see docs/gdtms-v2-api/mobile-api-requirements.md).
String get _kVersionManifestUrl {
  final base = apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
  return '${base}mobile-version.json';
}

/// App Store URL used on iOS (direct APK sideloading is not allowed on iOS).
const _kIosAppStoreUrl = 'https://apps.apple.com/app/idYOUR_APP_ID';

/// Handles all update-lifecycle operations:
/// version checks, APK downloads, checksum verification, and install launch.
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
      final downloadUrl = (json['download_url'] as String? ?? '').trim();

      if (latestVersion.isEmpty || downloadUrl.isEmpty) return null;
      if (!UpdateInfo.isNewerVersion(latestVersion, currentVersion)) {
        return null; // already up to date
      }

      return UpdateInfo.fromJson(json, currentVersion: currentVersion);
    } catch (e) {
      debugPrint('[UpdateService] checkForUpdate silently failed: $e');
      return null;
    }
  }

  // ── Download ───────────────────────────────────────────────────────────────

  /// Downloads the APK from [url] to the app's temp directory and calls
  /// [onProgress] with a value in [0, 1] as bytes arrive.
  ///
  /// Returns the local file path on success.
  /// Throws a descriptive [UpdateDownloadException] on failure.
  Future<String> downloadUpdate(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final normalizedUrl = _normalizeUrl(url);
    final destDir = await _updateDir();
    final destFile = File('${destDir.path}/app-latest.apk');

    // Clean up any leftover partial file from a previous attempt.
    await _cleanUpdateDir(destDir);

    try {
      await _dio.download(
        normalizedUrl,
        destFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received / total);
        },
        options: Options(receiveTimeout: const Duration(minutes: 10)),
      );
      return destFile.path;
    } on DioException catch (e) {
      // Delete any partial file so retry starts clean.
      await _safeDelete(destFile);

      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw UpdateDownloadException(
          'No internet connection or download timed out. Please retry.',
          type: UpdateDownloadErrorType.networkError,
        );
      }
      throw UpdateDownloadException(
        'Download interrupted: ${e.message}',
        type: UpdateDownloadErrorType.downloadInterrupted,
      );
    } catch (e) {
      await _safeDelete(destFile);
      throw UpdateDownloadException(
        'Unexpected download error: $e',
        type: UpdateDownloadErrorType.unknown,
      );
    }
  }

  // ── Checksum ───────────────────────────────────────────────────────────────

  /// Verifies that the file at [filePath] matches [expectedSha256].
  /// Throws [UpdateDownloadException] with [UpdateDownloadErrorType.checksumMismatch]
  /// if they do not match; deletes the corrupt file automatically.
  Future<void> verifyChecksum(String filePath, String expectedSha256) async {
    if (expectedSha256.isEmpty) return; // manifest has no checksum — skip

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final actual = sha256.convert(bytes).toString();

      if (actual != expectedSha256.toLowerCase()) {
        await _safeDelete(file);
        throw UpdateDownloadException(
          'Download corrupted — checksum mismatch. Please retry.',
          type: UpdateDownloadErrorType.checksumMismatch,
        );
      }
    } on UpdateDownloadException {
      rethrow;
    } catch (e) {
      throw UpdateDownloadException(
        'Checksum verification failed: $e',
        type: UpdateDownloadErrorType.unknown,
      );
    }
  }

  // ── Install ────────────────────────────────────────────────────────────────

  /// Launches the APK at [filePath] using the system package installer.
  /// On iOS, opens the App Store URL instead.
  ///
  /// Returns an [OpenResult] from `open_filex`; callers should check
  /// [OpenResult.type] for [ResultType.permissionDenied].
  Future<OpenResult> installUpdate(String filePath) async {
    if (Platform.isIOS) {
      final uri = Uri.parse(_kIosAppStoreUrl);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
      return OpenResult(type: ResultType.done, message: 'opened App Store');
    }
    return OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );
  }

  // ── Mandatory check ────────────────────────────────────────────────────────

  /// Returns `true` when the running version is below [minimumVersion].
  bool isMandatoryUpdate(String minimumVersion) {
    final current = AppVersionService.version;
    return UpdateInfo.isNewerVersion(minimumVersion, current);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<Directory> _updateDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/app_update');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _cleanUpdateDir(Directory dir) async {
    if (!dir.existsSync()) return;
    await for (final entity in dir.list()) {
      await _safeDelete(entity);
    }
  }

  Future<void> _safeDelete(FileSystemEntity entity) async {
    try {
      if (entity.existsSync()) await entity.delete();
    } catch (_) {}
  }

  String _normalizeUrl(String url) {
    if (url.startsWith('http')) return url;

    try {
      final uri = Uri.parse(apiBaseUrl);
      final hostBase =
          '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';

      if (url.startsWith('/')) {
        return '$hostBase$url';
      } else {
        // Prepend the directory part of the API base URL
        final base = apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
        return '$base$url';
      }
    } catch (e) {
      debugPrint('[UpdateService] URL normalization failed: $e');
      return url;
    }
  }
}

// ── Exceptions ────────────────────────────────────────────────────────────────

enum UpdateDownloadErrorType {
  networkError,
  downloadInterrupted,
  checksumMismatch,
  permissionDenied,
  unknown,
}

class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message, {required this.type});

  final String message;
  final UpdateDownloadErrorType type;

  @override
  String toString() => 'UpdateDownloadException[$type]: $message';
}
