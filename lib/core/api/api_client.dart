// DOCS: docs/development-standards.md
// DOCS: docs/core/api.md — update that file when you edit this one.

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/router/router_keys.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'api_result.dart';
export 'api_result.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';

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
        baseUrl: apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/',
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
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    final qStr = queryParameters != null ? ' $queryParameters' : '';
    debugPrint('[API] GET $relativePath$qStr');
    try {
      final response = await _dio.get<dynamic>(
        relativePath,
        queryParameters: queryParameters,
      );
      debugPrint('[API] GET $relativePath → ${response.statusCode}');
      return _mapResponse<T>(response, parser);
    } catch (e) {
      if (e is DioException && e.response != null) {
        debugPrint('[API] GET $relativePath ERROR DATA: ${e.response?.data}');
      }
      debugPrint('[API] GET $relativePath ERROR: $e');
      return _mapError<T>(e);
    }
  }

  Future<ApiResult<T>> post<T>(
    String path, {
    Map<String, dynamic>? data,
    required T Function(dynamic) parser,
  }) async {
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    try {
      final response = await _dio.post<dynamic>(relativePath, data: data);
      return _mapResponse<T>(response, parser);
    } catch (e) {
      if (e is DioException && e.response != null) {
        debugPrint('[API] POST $relativePath ERROR DATA: ${e.response?.data}');
      }
      return _mapError<T>(e);
    }
  }

  Future<ApiResult<T>> patch<T>(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? extraHeaders,
    required T Function(dynamic) parser,
  }) async {
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    try {
      debugPrint('[API] PATCH ${_dio.options.baseUrl}$relativePath');
      final options = extraHeaders != null
          ? Options(headers: extraHeaders)
          : null;
      final response = await _dio.patch<dynamic>(
        relativePath,
        data: data,
        options: options,
      );
      debugPrint('[API] PATCH $relativePath → ${response.statusCode}');
      return _mapResponse<T>(response, parser);
    } catch (e) {
      if (e is DioException && e.response != null) {
        debugPrint('[API] PATCH $relativePath ERROR DATA: ${e.response?.data}');
      }
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
  /// Uploads a file using server-provided pre-signed parameters (v3.3+).
  ///
  /// Steps:
  /// 1. Call GET /media/upload-params to get the target URL and fields.
  /// 2. POST to the target URL with fields + file (direct-to-storage).
  /// 3. Return the storage URL to the caller.
  Future<ApiResult<T>> uploadMedia<T>(
    String path, {
    String? barcode,
    required Uint8List bytes,
    required String filename,
    required String type,
    required T Function(dynamic) parser,
  }) async {
    final mimeType = filename.endsWith('.png') ? 'image/png' : 'image/jpeg';

    // Step 1: Fetch upload parameters from the API.
    final uploadType = type.toUpperCase();

    debugPrint(
      '[UPLOAD] Fetching params for type=$uploadType (barcode=$barcode)',
    );
    final paramsResult = await get<Map<String, dynamic>>(
      'media/upload-params',
      queryParameters: {
        'type': uploadType,
        if (barcode != null) 'barcode': barcode,
      },
      parser: parseApiMap,
    );

    if (paramsResult is ApiSuccess<Map<String, dynamic>>) {
      final data = paramsResult.data;
      final uploadUrl = (data['upload_url'] ?? data['url'])?.toString();
      final fields = data['fields'];
      final uploadMethod = (data['method'] ?? 'POST').toString().toUpperCase();

      if (uploadUrl != null && fields is Map<String, dynamic>) {
        debugPrint('[UPLOAD] Direct upload to: $uploadUrl');
        try {
          final formDataMap = <String, dynamic>{...fields};
          formDataMap['file'] = MultipartFile.fromBytes(
            bytes,
            filename: filename,
            contentType: MediaType.parse(mimeType),
          );

          final uploadResponse = await Dio().request<dynamic>(
            uploadUrl,
            data: FormData.fromMap(formDataMap),
            options: Options(method: uploadMethod),
          );

          if (uploadResponse.statusCode != null &&
              uploadResponse.statusCode! >= 200 &&
              uploadResponse.statusCode! < 300) {
            // S3 standard POST returns 204 No Content or 200 OK.
            // The object URL is usually the base URL + the 'key' field.
            final key = fields['key']?.toString();
            final finalUrl = uploadUrl.endsWith('/')
                ? '$uploadUrl$key'
                : '$uploadUrl/$key';

            debugPrint('[UPLOAD] Success: $finalUrl');
            return ApiSuccess<T>(
              parser({
                'data': {'url': finalUrl},
              }),
            );
          }
          debugPrint(
            '[UPLOAD] Direct upload failed: ${uploadResponse.statusCode}',
          );
          if (kStorageStrictMode) {
            return ApiServerError<T>(
              'Direct upload failed (HTTP ${uploadResponse.statusCode}) and strict mode is enabled.',
            );
          }
        } catch (e) {
          debugPrint('[UPLOAD] Direct upload exception: $e');
          if (kStorageStrictMode) {
            return ApiServerError<T>(
              'Direct upload failed (Exception: $e) and strict mode is enabled.',
            );
          }
        }
      }
    }

    // Step 2: Fallback to Legacy API upload if direct upload is unavailable or fails.
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    debugPrint('[UPLOAD] Falling back to API upload: $relativePath');
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
        'type': uploadType,
      });
      // Use a fresh Dio instance with auth token but without the global
      // Content-Type: application/json header, which breaks multipart parsing.
      final token = await _authStorage.getToken();
      final fallbackDio = Dio(
        BaseOptions(
          baseUrl: _dio.options.baseUrl,
          connectTimeout: _dio.options.connectTimeout,
          receiveTimeout: _dio.options.receiveTimeout,
          sendTimeout: _dio.options.sendTimeout,
          headers: {
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );
      final response = await fallbackDio.post<dynamic>(
        relativePath,
        data: formData,
      );
      return _mapResponse<T>(response, parser);
    } catch (e) {
      if (e is DioException && e.response != null) {
        debugPrint('[UPLOAD] API fallback ERROR DATA: ${e.response?.data}');
      }
      debugPrint('[UPLOAD] API fallback failed: $e');
      return _mapError<T>(e);
    }
  }
}
