extension StatusStringFormat on String {
  String toDisplayStatus() {
    if (isEmpty) return '—';
    return replaceAll('_', ' ').toUpperCase();
  }
}
