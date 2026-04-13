// DOCS: docs/core/models.md — update that file when you edit this one.

class BugReportLog {
  const BugReportLog({
    required this.level,
    required this.context,
    required this.message,
    required this.createdAt,
  });

  /// "ERROR" or "INFO"
  final String level;

  /// "ScreenName" or similar context
  final String context;

  /// Log message
  final String message;

  /// UNIX_TIMESTAMP
  final int createdAt;

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'context': context,
      'message': message,
      'created_at': createdAt,
    };
  }
}

class BugReportPayload {
  const BugReportPayload({
    required this.type,
    required this.severity,
    required this.appVersion,
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
    required this.deviceId,
    required this.message,
    this.userMessage,
    required this.logs,
  });

  /// MUST be one of: "bug", "enhancement", "task", "feedback" (Default to "bug").
  final String type;

  /// MUST be one of: "low", "medium", "high", "critical"
  final String severity;

  /// e.g., "1.2.3"
  final String appVersion;

  /// "ios" or "android"
  final String platform;

  /// Hardware model (e.g., "Samsung Galaxy S22" or "iPhone 14 Pro Max")
  final String deviceModel;

  /// e.g., "14.2.1" or "17.4"
  final String osVersion;

  /// Unique phone identifier
  final String deviceId;

  /// System generated high-level summary of the issue
  final String message;

  /// The verbatim reason/feedback typed by the courier
  final String? userMessage;

  /// Recent app logs
  final List<BugReportLog> logs;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'severity': severity,
      'app_version': appVersion,
      'platform': platform,
      'device_model': deviceModel,
      'os_version': osVersion,
      'device_id': deviceId,
      'message': message,
      if (userMessage != null && userMessage!.isNotEmpty)
        'user_message': userMessage,
      'logs': logs.map((log) => log.toJson()).toList(),
    };
  }
}
