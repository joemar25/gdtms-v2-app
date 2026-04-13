// DOCS: docs/shared/helpers.md — update that file when you edit this one.

extension StatusStringFormat on String {
  String toDisplayStatus() {
    if (isEmpty) return '—';
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
