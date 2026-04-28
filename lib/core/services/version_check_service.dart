// DOCS: docs/development-standards.md
// DOCS: docs/core/services.md — update that file when you edit this one.

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/services/app_version_service.dart';
import 'package:fsi_courier_app/core/services/error_log_service.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Checks the server for minimum and latest app versions.
///
/// Called once on every app startup from [SplashScreen._initialize].
/// If [force_update] is true and the current build is below [min_version],
/// a non-dismissible dialog is shown and the user cannot proceed until they
/// update.
class VersionCheckService {
  const VersionCheckService(this._api);

  final ApiClient _api;

  /// Performs the version check. Shows a blocking dialog on [context] if a
  /// force update is required. Returns immediately if the server is unreachable.
  Future<void> check(BuildContext context) async {
    try {
      final result = await _api.get<Map<String, dynamic>>(
        '/app/version',
        parser: (data) {
          if (data is Map<String, dynamic>) return data;
          if (data is Map && data['data'] is Map<String, dynamic>) {
            return data['data'] as Map<String, dynamic>;
          }
          return <String, dynamic>{};
        },
      );

      if (result is! ApiSuccess<Map<String, dynamic>>) return;

      final serverData = result.data;
      final minVersion = serverData['min_version']?.toString() ?? '';
      final forceUpdate = serverData['force_update'] == true;

      if (!forceUpdate || minVersion.isEmpty) return;
      if (!context.mounted) return;

      final current = AppVersionService.version;

      if (_isVersionBelow(current, minVersion)) {
        if (!context.mounted) return;
        await _showForceUpdateDialog(context);
      }
    } catch (e) {
      await ErrorLogService.warning(
        context: 'version_check',
        message: 'Version check failed',
        detail: e.toString(),
      );
    }
  }

  /// Returns true if [current] is strictly less than [minimum].
  /// Both versions must be in "major.minor.patch" format.
  bool _isVersionBelow(String current, String minimum) {
    try {
      final c = current.split('.').map(int.parse).toList();
      final m = minimum.split('.').map(int.parse).toList();
      for (var i = 0; i < 3; i++) {
        final cv = i < c.length ? c[i] : 0;
        final mv = i < m.length ? m[i] : 0;
        if (cv < mv) return true;
        if (cv > mv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showForceUpdateDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
          title: Text(
            'Update Required',
            style: DSTypography.body().copyWith(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'A new version of the FSI Courier app is required. '
            'Please update to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                const storeUrl =
                    'https://play.google.com/store/apps/details?id=com.fsi.courier';
                final uri = Uri.parse(storeUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}
