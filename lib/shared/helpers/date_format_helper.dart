import 'package:intl/intl.dart';

/// Formats an ISO-8601 date string for display.
///
/// [includeTime] — when true, appends the time (e.g. "Mar 9, 2025 · 3:59 PM").
/// Returns "—" for null/empty input; returns [iso] unchanged on parse error.
String formatDate(String? iso, {bool includeTime = false}) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return includeTime
        ? DateFormat('MMM d, yyyy · h:mm a').format(dt)
        : DateFormat('MMM d, yyyy').format(dt);
  } catch (_) {
    return iso;
  }
}
