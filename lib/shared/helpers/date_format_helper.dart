import 'package:intl/intl.dart';

/// Parses an ISO-8601 date string, treating it as UTC if it lacks timezone info.
DateTime? parseServerDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    var dateStr = iso.trim();
    if (!dateStr.contains('T')) {
      dateStr = dateStr.replaceFirst(' ', 'T');
    }
    final parts = dateStr.split('T');
    if (parts.length == 2) {
      final timePart = parts[1];
      if (!timePart.endsWith('Z') &&
          !timePart.contains('+') &&
          !timePart.contains('-')) {
        dateStr += 'Z';
      }
    }
    return DateTime.parse(dateStr);
  } catch (_) {
    return null;
  }
}

/// Formats an ISO-8601 date string for display.
///
/// [includeTime] — when true, appends the time (e.g. "Mar 9, 2025 · 3:59 PM").
/// Returns "—" for null/empty input; returns [iso] unchanged on parse error.
String formatDate(String? iso, {bool includeTime = false}) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = parseServerDate(iso);
  if (dt == null) return iso;

  final localDt = dt.toLocal();
  return includeTime
      ? DateFormat('MMM d, yyyy · h:mm a').format(localDt)
      : DateFormat('MMM d, yyyy').format(localDt);
}
