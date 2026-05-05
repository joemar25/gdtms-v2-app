// DOCS: docs/development-standards.md
// DOCS: docs/core/api.md — update that file when you edit this one.

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
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

  /// Generates an AWS Signature V4 pre-signed PUT URL for direct S3 upload.
  ///
  /// Only 'host' is in SignedHeaders; no Content-Type is signed so the client
  /// can PUT raw bytes without any header restrictions.
  String _presignedPutUrl({
    required String bucket,
    required String region,
    required String accessKey,
    required String secretKey,
    required String key,
    int expiresIn = 3600,
  }) {
    final now = DateTime.now().toUtc();
    final dateStr =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final dateTimeStr =
        '${dateStr}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z';

    final host = '$bucket.s3.$region.amazonaws.com';
    final credentialScope = '$dateStr/$region/s3/aws4_request';
    final credential = '$accessKey/$credentialScope';

    // Query params must be sorted by key name.
    final queryParams = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': credential,
      'X-Amz-Date': dateTimeStr,
      'X-Amz-Expires': '$expiresIn',
      'X-Amz-SignedHeaders': 'host',
    };
    final sortedKeys = queryParams.keys.toList()..sort();
    final canonicalQueryString = sortedKeys
        .map(
          (k) =>
              '${Uri.encodeComponent(k)}=${Uri.encodeComponent(queryParams[k]!)}',
        )
        .join('&');

    // S3 keys can contain slashes — encode each segment individually.
    final encodedKey = key.split('/').map(Uri.encodeComponent).join('/');

    final canonicalRequest = [
      'PUT',
      '/$encodedKey',
      canonicalQueryString,
      'host:$host\n', // canonical headers (trailing newline required)
      'host', // signed headers
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    final canonicalHash = sha256
        .convert(utf8.encode(canonicalRequest))
        .toString();

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      dateTimeStr,
      credentialScope,
      canonicalHash,
    ].join('\n');

    List<int> hmac(List<int> key, String data) =>
        Hmac(sha256, key).convert(utf8.encode(data)).bytes;

    final signingKey = hmac(
      hmac(hmac(hmac(utf8.encode('AWS4$secretKey'), dateStr), region), 's3'),
      'aws4_request',
    );
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign)).toString();

    return 'https://$host/$encodedKey?$canonicalQueryString&X-Amz-Signature=$signature';
  }

  /// Uploads a file directly to S3.
  ///
  /// Flow:
  ///   1. GET /media/upload-params → backend returns the intended S3 key/path.
  ///   2. Generate a pre-signed PUT URL client-side (AWS SigV4) using the
  ///      credentials in dart_defines.json — backend credential type is irrelevant.
  ///   3. PUT raw bytes to S3; strip query params → permanent object URL.
  Future<ApiResult<T>> uploadMedia<T>({
    String? barcode,
    required Uint8List bytes,
    required String filename,
    required String type,
    required T Function(dynamic) parser,
  }) async {
    final uploadType = type.toUpperCase();
    debugPrint(
      '[UPLOAD] Fetching params for type=$uploadType (barcode=$barcode)',
    );

    final paramsResult = await get<Map<String, dynamic>>(
      'media/upload-params',
      queryParameters: {'type': uploadType, 'barcode': ?barcode},
      parser: parseApiMap,
    );

    if (paramsResult is! ApiSuccess<Map<String, dynamic>>) {
      return ApiServerError<T>('Failed to fetch upload parameters.');
    }

    final data = paramsResult.data;
    final inner = data['data'] is Map<String, dynamic>
        ? data['data'] as Map<String, dynamic>
        : data;
    final serverUrl = (inner['upload_url'] ?? inner['url'])?.toString() ?? '';

    if (serverUrl.isEmpty) {
      return ApiServerError<T>('No upload URL returned from server.');
    }

    // Parse the S3 key from the URL path (strip bucket host + leading slash).
    // URL form: https://{bucket}.s3.{region}.amazonaws.com/{key}?...
    final uri = Uri.tryParse(serverUrl);
    final s3Key = uri?.path.replaceFirst('/', ''); // remove leading '/'

    if (s3Key == null || s3Key.isEmpty) {
      return ApiServerError<T>('Could not parse S3 key from server URL.');
    }

    // Generate a proper pre-signed PUT URL using client-side credentials.
    final putUrl = _presignedPutUrl(
      bucket: kAwsBucket,
      region: kAwsRegion,
      accessKey: kAwsAccessKeyId,
      secretKey: kAwsSecretAccessKey,
      key: s3Key,
    );

    debugPrint(
      '[UPLOAD] PUT (client-signed) ${'https://$kAwsBucket.s3.$kAwsRegion.amazonaws.com/$s3Key'}',
    );
    try {
      final httpClient = HttpClient();
      final request = await httpClient.putUrl(Uri.parse(putUrl));
      request.contentLength = bytes.length;
      request.add(bytes);
      final httpResponse = await request.close();
      final statusCode = httpResponse.statusCode;
      await httpResponse.drain<void>();
      httpClient.close();

      if (statusCode >= 200 && statusCode < 300) {
        final cleanUrl =
            'https://$kAwsBucket.s3.$kAwsRegion.amazonaws.com/$s3Key';
        debugPrint('[UPLOAD] Success: $cleanUrl');
        return ApiSuccess<T>(
          parser({
            'data': {'url': cleanUrl},
          }),
        );
      }

      debugPrint('[UPLOAD] S3 rejected with HTTP $statusCode');
      return ApiServerError<T>('S3 upload failed (HTTP $statusCode).');
    } catch (e) {
      debugPrint('[UPLOAD] Exception: $e');
      return ApiNetworkError<T>('Upload failed. Check connection.');
    }
  }
}
