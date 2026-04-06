import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/services/app_version_service.dart';
import 'package:fsi_courier_app/core/database/error_log_dao.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/core/services/error_log_service.dart';
import 'package:fsi_courier_app/core/models/bug_report_payload.dart';

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(
    apiClient: ref.read(apiClientProvider),
    authStorage: ref.read(authStorageProvider),
    deviceInfo: ref.read(deviceInfoProvider),
  );
});

/// Sends a bug/feedback report to the admin API.
///
/// Collects local error logs, device metadata, and an optional user message,
/// then POSTs to [POST /courier/reports].
class ReportService {
  const ReportService({
    required ApiClient apiClient,
    required AuthStorage authStorage,
    required DeviceInfoService deviceInfo,
  }) : _api = apiClient,
       _authStorage = authStorage,
       _deviceInfo = deviceInfo;

  final ApiClient _api;
  final AuthStorage _authStorage;
  final DeviceInfoService _deviceInfo;

  /// Submits a report.
  ///
  /// [type]        — 'bug' | 'task' | 'feedback' | 'enhancement'
  /// [userMessage] — optional free-text from the courier.
  /// [includeLogs] — whether to attach the last 50 local error log entries.
  Future<ApiResult<String>> submit({
    required String type,
    required String severity,
    required String summary,
    String? userMessage,
    bool includeLogs = true,
  }) async {
    try {
      final deviceModel = await _deviceInfo.deviceModel;
      final osVersion = await _deviceInfo.osVersion;
      final deviceId = await _authStorage.getDeviceId();
      final platform = Platform.isAndroid ? 'android' : 'ios';

      final List<BugReportLog> logs = includeLogs
          ? (await ErrorLogDao.instance.getAll(limit: 50))
                .map(
                  (e) => BugReportLog(
                    level: e.level,
                    context: e.context,
                    message: e.message,
                    createdAt: e.createdAt.millisecondsSinceEpoch,
                  ),
                )
                .toList()
          : [];

      // Use provided summary or fallback to generated message.
      final apiMessage =
          summary.trim().isNotEmpty ? summary : 'Courier submitted a $type report.';

      final payload = BugReportPayload(
        type: type,
        severity: severity,
        appVersion: AppVersionService.version,
        platform: platform,
        deviceModel: deviceModel,
        osVersion: osVersion,
        deviceId: deviceId,
        message: apiMessage,
        userMessage: userMessage?.trim(),
        logs: logs,
      );

      return await _api.post<String>(
        '/courier/reports',
        data: payload.toJson(),
        parser: (data) {
          if (data is Map) {
            // Handle {report_id: ...} and {data: {report_id: ...}} wrappers.
            final inner = data['data'];
            final map = inner is Map ? inner : data;
            return map['report_id']?.toString() ??
                map['reference']?.toString() ??
                map['id']?.toString() ??
                '';
          }
          return '';
        },
      );
    } catch (e) {
      await ErrorLogService.log(
        context: 'report',
        message: 'Failed to submit report',
        detail: e.toString(),
      );
      return ApiServerError<String>('Failed to submit report.');
    }
  }

  /// Auto-submits a crash/error report silently.
  ///
  /// Throttled — sends at most once every 30 minutes via SharedPreferences.
  static Future<void> autoSubmit({
    required ApiClient apiClient,
    required AuthStorage authStorage,
    required DeviceInfoService deviceInfo,
    required String errorDetail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSentMs = prefs.getInt('_auto_report_last_sent') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      const throttleMs = 30 * 60 * 1000; // 30 min

      if (nowMs - lastSentMs < throttleMs) return;

      await prefs.setInt('_auto_report_last_sent', nowMs);

      final service = ReportService(
        apiClient: apiClient,
        authStorage: authStorage,
        deviceInfo: deviceInfo,
      );
      await service.submit(
        type: 'bug', // mapped from 'crash' if needed, but 'bug' is safer.
        severity: 'critical',
        summary: 'AUTOMATED_CRASH_REPORT',
        userMessage: errorDetail,
        includeLogs: true,
      );
    } catch (_) {
      // Never let auto-report failures surface to the user.
    }
  }
}
