import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'api_result.dart';
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
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
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
            await _authStorage.clearAll();
            onUnauthorized?.call();
            showAppSnackbar(
              null,
              'Session expired. Please log in again.',
              type: SnackbarType.error,
            );
            await Future.delayed(const Duration(seconds: 2));
            final navContext = rootNavigatorKey.currentContext;
            if (navContext != null) {
              // ignore: use_build_context_synchronously
              navContext.go('/login');
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final AuthStorage _authStorage;
  final VoidCallback? onUnauthorized;
  late final Dio _dio;

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

    if (status == 429) {
      return ApiRateLimited<T>(
        'Too many attempts, please wait.',
        retryAfterSeconds: _parseRetryAfterSeconds(response),
      );
    }

    if (status == 409) {
      return ApiConflict<T>(
        _extractMessage(response.data, fallback: 'Request conflict.'),
      );
    }

    if (status == 401) {
      return ApiUnauthorized<T>();
    }

    return ApiServerError<T>(_extractMessage(response.data));
  }

  ApiResult<T> _mapError<T>(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.unknown) {
        return ApiNetworkError<T>('No connection. Please check your internet.');
      }

      final response = error.response;
      if (response != null) {
        final status = response.statusCode ?? 500;
        if (status == 401) {
          return ApiUnauthorized<T>();
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
          );
        }
        if (status == 422) {
          return ApiValidationError<T>(
            _extractValidationErrors(response.data),
            message: _extractMessage(response.data, fallback: ''),
          );
        }

        return ApiServerError<T>(_extractMessage(response.data));
      }
    }

    return ApiServerError<T>('Something went wrong.');
  }

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic) parser,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return _mapResponse<T>(response, parser);
    } catch (e) {
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
    required T Function(dynamic) parser,
  }) async {
    try {
      debugPrint('[API] PATCH ${_dio.options.baseUrl}$path');
      debugPrint('[API] payload: $data');
      final response = await _dio.patch<dynamic>(path, data: data);
      debugPrint('[API] response ${response.statusCode}: ${response.data}');
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

    // When USE_S3_UPLOAD=false, ALL types go through the API upload endpoint
    // (/deliveries/:barcode/media accepts: pod, selfie, recipient_signature, other).
    // When USE_S3_UPLOAD=true, skip the API endpoint entirely and push directly to S3.
    final needsS3 =
        kUseS3Upload &&
        awsAccessKeyId.isNotEmpty &&
        awsSecretAccessKey.isNotEmpty;

    // ── S3 direct upload ────────────────────────────────────────────────────
    if (needsS3) {
      if (awsAccessKeyId.isEmpty || awsSecretAccessKey.isEmpty) {
        debugPrint('[UPLOAD] S3 required but credentials are empty.');
        return ApiServerError<T>(
          'AWS credentials are required to upload "$type" media. '
          'Add AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY via --dart-define-from-file.',
        );
      }
      // Derive barcode from path: '/deliveries/BARCODE/media' → BARCODE
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      final barcode = segments.length >= 2 ? segments[1] : 'unknown';
      final ext = filename.endsWith('.png') ? 'png' : 'jpg';
      final s3Key =
          'deliveries/$barcode/images/${type}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      debugPrint(
        '[UPLOAD] S3 upload: type=$type s3Key=$s3Key (${bytes.length}b)',
      );
      final url = await S3UploadService.upload(
        bytes: bytes,
        mimeType: mimeType,
        s3Key: s3Key,
      );
      if (url != null) {
        debugPrint('[UPLOAD] S3 success: $url');
        return ApiSuccess<T>(
          parser({
            'data': {'url': url},
          }),
        );
      }
      debugPrint('[UPLOAD] S3 failed for type=$type s3Key=$s3Key');
      return ApiServerError<T>(
        'S3 upload failed. Check AWS credentials and bucket permissions.',
      );
    }

    // ── API upload (pod / selfie only) ──────────────────────────────────────
    debugPrint('[UPLOAD] API upload: type=$type path=$path (${bytes.length}b)');
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: {
          'file_data': base64Encode(bytes),
          'mime_type': mimeType,
          'type': type,
        },
      );
      debugPrint('[UPLOAD] API response status=${response.statusCode} body=${response.data.toString().substring(0, response.data.toString().length.clamp(0, 300))}');
      return _mapResponse<T>(response, parser);
    } catch (e) {
      debugPrint('[UPLOAD] API upload exception: $e');
      return _mapError<T>(e);
    }
  }
}
