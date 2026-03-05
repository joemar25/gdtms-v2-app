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
            final navContext = rootNavigatorKey.currentContext;
            if (navContext != null) {
              // ignore: use_build_context_synchronously
              navContext.go('/login');
            }
            showAppSnackbar(
              null,
              "You've been logged out.",
              type: SnackbarType.error,
            );
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
      final response = await _dio.patch<dynamic>(path, data: data);
      return _mapResponse<T>(response, parser);
    } catch (e) {
      return _mapError<T>(e);
    }
  }
}
