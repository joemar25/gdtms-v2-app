// DOCS: docs/development-standards.md
// DOCS: docs/shared/helpers.md — update that file when you edit this one.

String resolveDeliveryIdentifier(Map<String, dynamic> delivery) {
  return (delivery['barcode'] ?? '').toString().trim();
}
