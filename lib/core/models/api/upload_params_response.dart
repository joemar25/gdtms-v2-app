/// Response model for the direct upload parameters endpoint.
///
/// Endpoint: `GET /api/mbl/media/upload-params`
class UploadParamsResponse {
  final bool success;
  final UploadData data;

  UploadParamsResponse({required this.success, required this.data});

  factory UploadParamsResponse.fromJson(Map<String, dynamic> json) {
    return UploadParamsResponse(
      success: json['success'] ?? false,
      data: UploadData.fromJson(json['data'] ?? {}),
    );
  }
}

class UploadData {
  final String uploadUrl;
  final Map<String, String> fields;
  final String method;

  UploadData({
    required this.uploadUrl,
    required this.fields,
    this.method = 'POST',
  });

  factory UploadData.fromJson(Map<String, dynamic> json) {
    return UploadData(
      uploadUrl: json['upload_url'] ?? '',
      fields: Map<String, String>.from(json['fields'] ?? {}),
      method: json['method'] ?? 'POST',
    );
  }

  /// Get the target key (path) from the fields map.
  String? get key => fields['key'];
}
