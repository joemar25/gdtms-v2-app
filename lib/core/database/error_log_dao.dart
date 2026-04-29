// DOCS: docs/development-standards.md
// DOCS: docs/core/database.md — update that file when you edit this one.

import 'package:fsi_courier_app/core/database/app_database.dart';

class ErrorLogEntry {
  const ErrorLogEntry({
    required this.id,
    required this.level,
    required this.context,
    required this.message,
    this.detail,
    this.barcode,
    required this.createdAt,
  });

  final int id;
  final String level; // 'error' | 'warning'
  final String context; // 'sync', 'delivery_update', 'api', 'scan', etc.
  final String message;
  final String? detail;
  final String? barcode;
  final DateTime createdAt;

  factory ErrorLogEntry.fromMap(Map<String, dynamic> map) {
    return ErrorLogEntry(
      id: map['id'] as int,
      level: map['level'] as String,
      context: map['context'] as String,
      message: map['message'] as String,
      detail: map['detail'] as String?,
      barcode: map['barcode'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

class ErrorLogDao {
  ErrorLogDao._();
  static final ErrorLogDao instance = ErrorLogDao._();

  Future<void> insert({
    required String level,
    required String context,
    required String message,
    String? detail,
    String? barcode,
  }) async {
    final db = await AppDatabase.getInstance();
    await db.insert('error_logs', {
      'level': level,
      'context': context,
      'message': message,
      'detail': detail,
      'barcode': barcode,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<ErrorLogEntry>> getAll({int limit = 200}) async {
    final db = await AppDatabase.getInstance();
    final rows = await db.query(
      'error_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ErrorLogEntry.fromMap).toList();
  }

  /// Returns the most recent [limit] log entries as raw maps for API submission.
  Future<List<Map<String, dynamic>>> getRecentLogs({int limit = 50}) async {
    final db = await AppDatabase.getInstance();
    final rows = await db.query(
      'error_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((row) {
      final ts = row['created_at'] as int?;
      return {
        'level': row['level'],
        'context': row['context'],
        'message': row['message'],
        'detail': row['detail'],
        'barcode': row['barcode'],
        'occurred_at': ts != null
            ? DateTime.fromMillisecondsSinceEpoch(ts).toUtc().toIso8601String()
            : null,
      };
    }).toList();
  }

  Future<int> getCount() async {
    final db = await AppDatabase.getInstance();
    final result = await db.rawQuery('SELECT COUNT(*) FROM error_logs');
    return (result.first.values.first as int?) ?? 0;
  }

  Future<void> clearAll() async {
    final db = await AppDatabase.getInstance();
    await db.delete('error_logs');
  }

  /// Auto-prune entries older than [retentionMs] milliseconds.
  Future<void> deleteOld(int retentionMs) async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - retentionMs;
    final db = await AppDatabase.getInstance();
    await db.delete('error_logs', where: 'created_at < ?', whereArgs: [cutoff]);
  }

  Future<void> deleteByContext(String context, {String? message}) async {
    final db = await AppDatabase.getInstance();
    if (message != null) {
      await db.delete(
        'error_logs',
        where: 'context = ? AND message = ?',
        whereArgs: [context, message],
      );
    } else {
      await db.delete('error_logs', where: 'context = ?', whereArgs: [context]);
    }
  }

  Future<void> deleteById(int id) async {
    final db = await AppDatabase.getInstance();
    await db.delete('error_logs', where: 'id = ?', whereArgs: [id]);
  }
}
