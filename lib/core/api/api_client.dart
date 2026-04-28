// DOCS: docs/core/api.md — update that file when you edit this one.

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/services/error_log_service.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'api_result.dart';
export 'api_result.dart';
import 's3_upload_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    authStorage: ref.read(authStorageProvider),
    onUnauthorized: () => ref.read(authProvider.notifier).clearAuth(),
  );
});

class ApiClient {
  ApiClient({required AuthStorage authStorage, this.onUnauthorized})
    : _authStorage = authStorage {
    _dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: kApiConnectTimeout,
        receiveTimeout: kApiReceiveTimeout,
        sendTimeout: kApiSendTimeout,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            if (_handlingUnauthorized) {
              handler.next(error);
              return;
            }
            _handlingUnauthorized = true;
            await _authStorage.clearAll();
            onUnauthorized?.call();

            // Prefer server-provided message when available to avoid showing a
            // generic "Session expired" text that may duplicate API details.
            final serverMsg = _extractMessage(
              error.response?.data,
              fallback: 'Session expired. Please log in again.',
            );

            // Use top-overlay error notification for visibility.
            showErrorNotification(null, serverMsg);
            await Future.delayed(const Duration(seconds: 2));
            final navContext = rootNavigatorKey.currentContext;
            if (navContext != null) {
              // ignore: use_build_context_synchronously
              navContext.go('/login');
            }
            _handlingUnauthorized = false;
          }
          handler.next(error);
        },
      ),
    );
  }

  final AuthStorage _authStorage;
  final VoidCallback? onUnauthorized;
  late final Dio _dio;
  bool _handlingUnauthorized = false;

  Dio get dio => _dio;

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
    }
    return null;
  }

  int? _parseRetryAfterSeconds(Response<dynamic>? response) {
    final headerValue = response?.headers.value('retry-after');
    if (headerValue == null) return null;
    return int.tryParse(headerValue.trim());
  }

  String _extractMessage(
    dynamic data, {
    String fallback = 'Something went wrong.',
  }) {
    final map = _asStringDynamicMap(data);
    final message = map?['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    return fallback;
  }

  Map<String, List<String>> _extractValidationErrors(dynamic data) {
    final parsed = <String, List<String>>{};
    final map = _asStringDynamicMap(data);
    final rawErrors = map?['errors'];
    final errorMap = _asStringDynamicMap(rawErrors);
    if (errorMap == null) return parsed;

    for (final entry in errorMap.entries) {
      final value = entry.value;
      parsed[entry.key] = value is List
          ? value.map((e) => e.toString()).toList()
          : [value.toString()];
    }

    return parsed;
  }

  ApiResult<T> _mapResponse<T>(
    Response<dynamic> response,
    T Function(dynamic) parser,
  ) {
    final status = response.statusCode ?? 500;

    if (status >= 200 && status < 300) {
      return ApiSuccess<T>(parser(response.data));
    }

    if (status == 422) {
      final parsed = _extractValidationErrors(response.data);
      return ApiValidationError<T>(
        parsed,
        message: _extractMessage(response.data, fallback: ''),
      );
    }

    if (status == 400) {
      return ApiBadRequest<T>(
        _extractMessage(response.data, fallback: 'Bad request.'),
      );
    }

    if (status == 429) {
      return ApiRateLimited<T>(
        'Too many attempts, please wait.',
        retryAfterSeconds: _parseRetryAfterSeconds(response),
      );
    }

    if (status == 409) {
      return ApiConflict<T>(
        _extractMessage(response.data, fallback: 'Request conflict.'),
        data: response.data,
      );
    }

    if (status == 401) {
      return ApiUnauthorized<T>(_extractMessage(response.data));
    }

    return ApiServerError<T>(_extractMessage(response.data));
  }

  ApiResult<T> _mapError<T>(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.unknown) {
        return ApiNetworkError<T>('Network error. Check connection.');
      }

      final response = error.response;
      if (response != null) {
        final status = response.statusCode ?? 500;
        if (status == 401) {
          return ApiUnauthorized<T>(_extractMessage(response.data));
        }
        if (status == 429) {
          return ApiRateLimited<T>(
            'Rate limited. Please wait.',
            retryAfterSeconds: _parseRetryAfterSeconds(response),
          );
        }
        if (status == 409) {
          return ApiConflict<T>(
            _extractMessage(response.data, fallback: 'Conflict error.'),
            data: response.data,
          );
        }
        if (status == 422) {
          return ApiValidationError<T>(
            _extractValidationErrors(response.data),
            message: _extractMessage(
              response.data,
              fallback: 'Validation failed.',
            ),
          );
        }
        if (status == 400) {
          return ApiBadRequest<T>(
            _extractMessage(response.data, fallback: 'Bad request.'),
          );
        }

        return ApiServerError<T>(
          _extractMessage(response.data, fallback: 'Server error.'),
        );
      }
    }

    return ApiServerError<T>('An unexpected error occurred.');
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic) parser,
  }) async {
    final qStr = queryParameters != null ? ' $queryParameters' : '';
    debugPrint('[API] GET $path$qStr');
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      debugPrint('[API] GET $path → ${response.statusCode}');
      return _mapResponse<T>(response, parser);
    } catch (e) {
      debugPrint('[API] GET $path ERROR: $e');
      return _mapError<T>(e);
    }
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    Map<String, dynamic>? data,
    required T Function(dynamic) parser,
  }) async {
    try {
      final response = await _dio.post<dynamic>(path, data: data);
      return _mapResponse<T>(response, parser);
    } catch (e) {
      return _mapError<T>(e);
    }
  }

  Future<ApiResult<T>> patch<T>(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? extraHeaders,
    required T Function(dynamic) parser,
  }) async {
    try {
      debugPrint('[API] PATCH ${_dio.options.baseUrl}$path');
      final options = extraHeaders != null
          ? Options(headers: extraHeaders)
          : null;
      final response = await _dio.patch<dynamic>(
        path,
        data: data,
        options: options,
      );
      debugPrint('[API] PATCH $path → ${response.statusCode}');
      return _mapResponse<T>(response, parser);
    } catch (e) {
      debugPrint('[API] PATCH error: $e');
      return _mapError<T>(e);
    }
  }

  /// Uploads a file to S3 or the API media endpoint.
  ///
  /// Routing rules:
  ///  • [kUseS3Upload]=true  AND credentials present  → S3 for all types.
  ///  • type is NOT pod/selfie (i.e. recipient_signature, other)           → S3
  ///    forced, because the API upload endpoint only accepts pod / selfie.
  ///    Requires AWS credentials; returns [ApiServerError] if absent.
  ///  • type is pod/selfie AND [kUseS3Upload]=false                        → API
  ///    JSON endpoint: POST { file_data, mime_type, type }.
  ///
  /// S3 key structure: `deliveries/{barcode}/images/{type}_{ts}.{ext}`
  ///
  /// [path]     — e.g. `/deliveries/BARCODE/media` (used to extract barcode).
  /// [bytes]    — raw file bytes.
  /// [filename] — e.g. `'pod.jpg'` / `'signature.png'` (derives mime_type).
  /// [type]     — upload type: `pod` | `selfie` | `recipient_signature` | `other`.
  Future<ApiResult<T>> uploadMedia<T>(
    String path, {
    required Uint8List bytes,
    required String filename,
    required String type,
    required T Function(dynamic) parser,
  }) async {
    final mimeType = filename.endsWith('.png') ? 'image/png' : 'image/jpeg';

    // When kUseS3Upload=true AND credentials are present, try S3 first.
    // If S3 fails for any reason, fall through to the API upload endpoint.
    // Only mark as fully failed when both paths are exhausted.
    final needsS3 =
        kUseS3Upload &&
        awsAccessKeyId.isNotEmpty &&
        awsSecretAccessKey.isNotEmpty;

    // ── S3 direct upload (primary, when enabled) ────────────────────────────
    if (needsS3) {
      // Derive barcode/ID from path.
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      final String folder;
      final String identifier;

      if (segments.first == 'me') {
        folder = 'couriers';
        // For profile, we can use 'profile' as the identifier or try to get courier ID.
        // Since we don't have easy access to courier ID here without async,
        // we'll use 'me' and let the S3 prefix be couriers/me/profile_picture.
        // Alternatively, the caller could provide the ID in the path if we changed the API structure.
        // For now, let's stick to a descriptive path.
        identifier = 'me';
      } else {
        folder = 'deliveries';
        identifier = segments.length >= 2 ? segments[1] : 'unknown';
      }

      final ext = filename.endsWith('.png') ? 'png' : 'jpg';
      final s3Key = segments.first == 'me'
          ? '$folder/$identifier/profile/profile_picture_${DateTime.now().millisecondsSinceEpoch}.$ext'
          : '$folder/$identifier/images/${type}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      debugPrint(
        '[UPLOAD] S3 upload: type=$type s3Key=$s3Key (${bytes.length}b)',
      );
      final s3Result = await S3UploadService.upload(
        bytes: bytes,
        mimeType: mimeType,
        s3Key: s3Key,
      );
      if (s3Result.url != null) {
        debugPrint('[UPLOAD] S3 success: ${s3Result.url}');
        return ApiSuccess<T>(
          parser({
            'data': {'url': s3Result.url},
          }),
        );
      }
      // S3 failed.
      final s3Err = s3Result.error ?? 'unknown';
      if (kS3StrictMode) {
        // Strict mode: no API fallback — surface S3 failure immediately.
        debugPrint(
          '[UPLOAD] S3 failed ($type) — strict mode, not falling back. $s3Err',
        );
        await ErrorLogService.log(
          context: 'api',
          message: 'S3 upload failed (strict mode, no API fallback) ($type)',
          detail: 'key=$s3Key\n$s3Err',
          barcode: identifier,
        );
        return ApiServerError<T>('S3 upload failed: $s3Err');
      }
      debugPrint(
        '[UPLOAD] S3 failed ($type) — $s3Err. Falling back to API upload…',
      );
      await ErrorLogService.warning(
        context: 'api',
        message: 'S3 upload failed, falling back to API ($type)',
        detail: 'key=$s3Key\n$s3Err',
        barcode: identifier,
      );
      // Do NOT return — fall through to API upload below.
    }

    // ── API upload (fallback when S3 fails, or primary when kUseS3Upload=false)
    // Endpoint: POST /deliveries/:barcode/media
    // Expects multipart/form-data with fields: file (binary), type (string).
    debugPrint('[UPLOAD] API upload: type=$type path=$path (${bytes.length}b)');
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final barcode = segments.first != 'me' && segments.length >= 2
        ? segments[1]
        : null;
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
        'type': type,
      });
      final response = await _dio.post<dynamic>(path, data: formData);
      debugPrint('[UPLOAD] API upload $type → ${response.statusCode}');
      return _mapResponse<T>(response, parser);
    } catch (e) {
      // Both S3 (if attempted) and API failed — log as a full error.
      debugPrint('[UPLOAD] API upload exception: $e');
      await ErrorLogService.log(
        context: 'api',
        message: 'All upload attempts failed ($type)',
        detail: e.toString(),
        barcode: barcode,
      );
      return _mapError<T>(e);
    }
  }
}
