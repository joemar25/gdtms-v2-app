class PhotoEntry {
  const PhotoEntry({required this.id, required this.file, required this.type});

  final String id;
  final String file;
  final String type;

  Map<String, dynamic> toApiJson() => {'file': file, 'type': type};
}
