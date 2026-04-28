// DOCS: docs/development-standards.md
// DOCS: docs/shared/helpers.md — update that file when you edit this one.

Map<String, dynamic> asStringDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

Map<String, dynamic> parseApiMap(dynamic json) => asStringDynamicMap(json);

Map<String, dynamic> mapFromKey(Map<String, dynamic> source, String key) {
  return asStringDynamicMap(source[key]);
}

List<Map<String, dynamic>> listOfMapsFromKey(
  Map<String, dynamic> source,
  String key,
) {
  final rawList = source[key];
  if (rawList is! List) return const <Map<String, dynamic>>[];
  return rawList
      .whereType<Map>()
      .map((item) => asStringDynamicMap(item))
      .toList();
}
