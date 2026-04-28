// DOCS: docs/development-standards.md
// DOCS: docs/shared/helpers.md — update that file when you edit this one.

String resolveDeliveryIdentifier(Map<String, dynamic> delivery) {
  final candidates = [
    delivery['barcode_value'],
    delivery['barcode'],
    delivery['tracking_number'],
  ];

  for (final value in candidates) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }

  return '';
}
