// DOCS: docs/development-standards.md
// DOCS: docs/core/services.md — update that file when you edit this one.

import 'package:fsi_courier_app/core/database/error_log_dao.dart';

/// Simple static service for logging errors/warnings to the local SQLite store.
/// Call [ErrorLogService.log] from any catch block or failure path.
class ErrorLogService {
  ErrorLogService._();

  static Future<void> log({
    required String context,
    required String message,
    String level = 'error',
    String? detail,
    String? barcode,
  }) async {
    try {
      await ErrorLogDao.instance.insert(
        level: level,
        context: context,
        message: message,
        detail: detail,
        barcode: barcode,
      );
    } catch (_) {
      // Never throw from the logging layer.
    }
  }

  static Future<void> warning({
    required String context,
    required String message,
    String? detail,
    String? barcode,
  }) => log(
    context: context,
    message: message,
    level: 'warning',
    detail: detail,
    barcode: barcode,
  );

  /// Clears specific logs programmatically when an issue is resolved.
  static Future<void> clearByContext(String context, {String? message}) async {
    try {
      await ErrorLogDao.instance.deleteByContext(context, message: message);
    } catch (_) {}
  }

  /// Manually resolve a specific log entry by ID.
  static Future<void> resolve(int id) async {
    try {
      await ErrorLogDao.instance.deleteById(id);
    } catch (_) {}
  }
}
