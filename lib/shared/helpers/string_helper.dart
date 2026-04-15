// DOCS: docs/shared/helpers.md — update that file when you edit this one.

import 'package:fsi_courier_app/core/models/delivery_status.dart';

extension StatusStringFormat on String {
  /// Converts a delivery status string to a display label.
  ///
  /// Known [DeliveryStatus] values use their canonical [DeliveryStatus.displayName]
  /// (e.g. 'FAILED_DELIVERY' → 'FAILED DELIVERY'). Unknown values fall back to
  /// replacing underscores with spaces and uppercasing.
  String toDisplayStatus() {
    if (isEmpty) return '—';
    final ds = DeliveryStatus.fromString(this);
    if (ds != DeliveryStatus.unknown) return ds.displayName.toUpperCase();
    // Fallback for non-delivery strings (e.g. timeline action labels).
    return replaceAll('_', ' ').toUpperCase();
  }
}

extension ContactStringFormat on String {
  /// Extracts the first phone number if multiple are separated by '/' or ','.
  String cleanContactNumber() {
    if (isEmpty) return '';
    final parts = split(RegExp(r'[/,]'));
    for (var part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }
}
