// DOCS: docs/development-standards.md

/// Holds metadata about a remote app update parsed from the version manifest.
///
/// [isMandatory] is computed at parse time by comparing [minimumVersion]
/// against the running app version; it is never serialised to disk.
class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.minimumVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.fileSizeMb,
    required this.checksumSha256,
    required this.isMandatory,
  });

  final String latestVersion;
  final String minimumVersion;
  final String downloadUrl;
  final String releaseNotes;
  final double fileSizeMb;
  final String checksumSha256;

  /// True when the running version is below [minimumVersion],
  /// meaning the user cannot dismiss the update prompt.
  final bool isMandatory;

  factory UpdateInfo.fromJson(
    Map<String, dynamic> json, {
    required String currentVersion,
  }) {
    final minimumVersion = (json['minimum_version'] as String? ?? '0.0.0')
        .trim();
    return UpdateInfo(
      latestVersion: (json['latest_version'] as String? ?? '').trim(),
      minimumVersion: minimumVersion,
      downloadUrl: (json['download_url'] as String? ?? '').trim(),
      releaseNotes: (json['release_notes'] as String? ?? '').trim(),
      fileSizeMb: (json['file_size_mb'] as num? ?? 0).toDouble(),
      checksumSha256: (json['checksum_sha256'] as String? ?? '').trim(),
      isMandatory: _isVersionBelow(currentVersion, minimumVersion),
    );
  }

  /// Returns true when [version] is strictly less than [threshold].
  /// Handles semantic versioning correctly (e.g. 1.10.0 > 1.9.0).
  static bool _isVersionBelow(String version, String threshold) {
    final v = _parseVersion(version);
    final t = _parseVersion(threshold);
    for (var i = 0; i < 3; i++) {
      if (v[i] < t[i]) return true;
      if (v[i] > t[i]) return false;
    }
    return false; // equal → not below
  }

  static List<int> _parseVersion(String v) {
    final parts = v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.take(3).toList();
  }

  /// Returns true when [a] is strictly greater than [b].
  static bool isNewerVersion(String a, String b) {
    final av = _parseVersion(a);
    final bv = _parseVersion(b);
    for (var i = 0; i < 3; i++) {
      if (av[i] > bv[i]) return true;
      if (av[i] < bv[i]) return false;
    }
    return false;
  }
}
