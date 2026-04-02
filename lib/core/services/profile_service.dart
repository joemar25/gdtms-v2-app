import 'dart:typed_data';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';

/// Service for profile-specific APIs such as uploading the courier's profile
/// picture. This keeps profile media uploads separate from delivery media
/// uploads and ensures the `type` field is always `profile_picture`.
class ProfileService {
  const ProfileService._();

  static const ProfileService instance = ProfileService._();

  /// Uploads a profile picture to the `/me/media` endpoint.
  ///
  /// Enforces the 10MB size limit and allowed file extensions.
  Future<ApiResult<Map<String, dynamic>>> uploadProfileMedia(
    ApiClient api, {
    required Uint8List bytes,
    required String filename,
  }) async {
    const maxBytes = 10 * 1024 * 1024; // 10 MB
    if (bytes.length > maxBytes) {
      return const ApiServerError<Map<String, dynamic>>(
        'File exceeds maximum allowed size of 10MB.',
      );
    }

    final lower = filename.toLowerCase();
    final allowedExt = ['.jpg', '.jpeg', '.png', '.webp'];
    final ok = allowedExt.any((e) => lower.endsWith(e));
    if (!ok) {
      return const ApiServerError<Map<String, dynamic>>(
        'Unsupported file type. Allowed: jpeg, jpg, png, webp.',
      );
    }

    try {
      final result = await api.uploadMedia<Map<String, dynamic>>(
        '/me/media',
        bytes: bytes,
        filename: filename,
        // Must be exactly this value for backend validation.
        type: 'profile_picture',
        parser: (d) {
          if (d is Map<String, dynamic>) return d;
          if (d is Map) return d.map((k, v) => MapEntry(k.toString(), v));
          return <String, dynamic>{};
        },
      );
      return result;
    } catch (e) {
      return ApiServerError<Map<String, dynamic>>(e.toString());
    }
  }
}
