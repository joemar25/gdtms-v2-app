// DOCS: docs/development-standards.md
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

/// Recipient and authorized-representative numbers resolved from a delivery map.
class DeliveryContactNumbers {
  const DeliveryContactNumbers({
    required this.recipient,
    required this.authRep,
  });

  final List<String> recipient;
  final List<String> authRep;
}

/// Parses one or more phone numbers from a single API contact field.
///
/// GDTMS may store multiple numbers using `/`, `,`, `;`, or `|` delimiters.
/// When no delimiter is present, numbers concatenated with whitespace before
/// a new `+63`, `09`, or `+` prefix are split into separate entries.
List<String> parseContactNumbers(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return [];

  final numbers = <String>[];
  for (final part in trimmed.split(RegExp(r'[/,;|]'))) {
    final segment = part.trim();
    if (segment.isEmpty) continue;
    numbers.addAll(_splitSpaceConcatenatedPhones(segment));
  }

  return numbers;
}

/// Splits a segment that contains multiple space-concatenated phone numbers.
List<String> _splitSpaceConcatenatedPhones(String value) {
  final parts = value
      .split(RegExp(r'\s+(?=\+63|09|\+)'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  return parts.isEmpty ? [value.trim()] : parts;
}

/// Normalises a phone value to digits-only for duplicate detection.
String normalizePhoneKey(String phone) => phone.replaceAll(RegExp(r'\D'), '');

/// Resolves recipient and auth-rep contact lists from a delivery JSON map.
///
/// Reads `recipient_phone` / `contact` for the recipient and
/// `contact_rep` / `auth_rep_number` for the authorized representative.
/// When the same number appears in both fields, it is shown only under
/// the authorized representative.
DeliveryContactNumbers resolveDeliveryContactNumbers(
  Map<String, dynamic> delivery,
) {
  final recipientRaw =
      delivery['recipient_phone']?.toString() ??
      delivery['contact']?.toString() ??
      '';
  final authRepRaw =
      delivery['contact_rep']?.toString() ??
      delivery['auth_rep_number']?.toString() ??
      '';

  final recipient = parseContactNumbers(recipientRaw);
  final authRep = parseContactNumbers(authRepRaw);

  if (authRep.isEmpty) {
    return DeliveryContactNumbers(recipient: recipient, authRep: authRep);
  }

  final authRepKeys = authRep.map(normalizePhoneKey).toSet();
  final dedupedRecipient = recipient
      .where((number) => !authRepKeys.contains(normalizePhoneKey(number)))
      .toList();

  return DeliveryContactNumbers(recipient: dedupedRecipient, authRep: authRep);
}

extension ContactStringFormat on String {
  /// Returns the first parsed phone number from a multi-value contact field.
  String cleanContactNumber() {
    final numbers = parseContactNumbers(this);
    return numbers.isEmpty ? '' : numbers.first;
  }
}
