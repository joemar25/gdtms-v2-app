// DOCS: docs/development-standards.md
// DOCS: docs/shared/helpers.md — update that file when you edit this one.

import 'package:intl/intl.dart';

/// Parses an ISO-8601 date string received from the server.
///
/// Behaviour:
/// - If the string contains an explicit timezone (Z or an offset) it is
///   parsed as provided.
/// - If the string lacks timezone information, we try parsing it as local
///   time first (Dart treats timezone-less ISO strings as local). If that
///   fails we fall back to treating the value as UTC by appending 'Z'.
///
/// This makes the client tolerant to servers that intermittently emit
/// naive datetimes (no timezone) that are intended to represent local times.
DateTime? parseServerDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    var dateStr = iso.trim();
    if (!dateStr.contains('T')) {
      dateStr = dateStr.replaceFirst(' ', 'T');
    }

    // If string ends with an explicit timezone (Z or +HH:MM / -HH:MM / +HHMM / +HH)
    // normalize it to a colon format that `DateTime.parse` accepts reliably.
    final tzSuffix = RegExp(r'(Z|[+\-]\d{2}(:?\d{2})?)$');
    final m = tzSuffix.firstMatch(dateStr);
    if (m != null) {
      final matched = m.group(0)!;
      if (matched != 'Z' && !matched.contains(':')) {
        // matched examples: +0800 or +08 => convert to +08:00
        String norm;
        final sign = matched.substring(0, 1);
        final digits = matched.substring(1);
        if (digits.length == 4) {
          // +HHMM -> +HH:MM
          norm = '$sign${digits.substring(0, 2)}:${digits.substring(2)}';
        } else if (digits.length == 2) {
          // +HH -> +HH:00
          norm = '$sign$digits:00';
        } else {
          norm = matched; // unexpected shape, leave as-is
        }
        dateStr = dateStr.substring(0, dateStr.length - matched.length) + norm;
      }
      return DateTime.parse(dateStr);
    }

    // Try parsing as local (Dart's DateTime.parse treats timezone-less as local).
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      // Fallback: treat as UTC by appending 'Z'.
      try {
        return DateTime.parse('${dateStr}Z');
      } catch (_) {
        return null;
      }
    }
  } catch (_) {
    return null;
  }
}

/// Formats an ISO-8601 date string for display.
///
/// [includeTime] — when true, appends the time (e.g. "Mar 9, 2025 · 3:59 PM").
/// Returns "—" for null/empty input; returns [iso] unchanged on parse error.
String formatDate(String? iso, {bool includeTime = false}) {
  if (iso == null || iso.isEmpty || iso == 'null') return '';
  final dt = parseServerDate(iso);
  if (dt == null) return iso;

  // Always present server times in Philippine Standard Time (UTC+8)
  // regardless of the device's local timezone. Convert the instant to UTC
  // then shift to +08:00 for display.
  final pst = dt.toUtc().add(const Duration(hours: 8));
  return includeTime
      ? DateFormat('MMM d, yyyy · h:mm a').format(pst)
      : DateFormat('MMM d, yyyy').format(pst);
}
