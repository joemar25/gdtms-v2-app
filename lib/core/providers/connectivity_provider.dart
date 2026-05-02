// DOCS: docs/development-standards.md
// DOCS: docs/core/providers.md — update that file when you edit this one.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fsi_courier_app/core/config.dart';

/// Streams the list of active [ConnectivityResult] values whenever the
/// network state changes.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

class ApiReachabilityNotifier extends Notifier<bool> {
  Timer? _timer;
  bool _disposed = false;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  @override
  bool build() {
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _dio.close();
    });
    _init();
    return false;
  }

  void _init() {
    // Ping immediately
    _ping();
    // Then every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _ping());
  }

  Future<void> _ping() async {
    final connectivity = ref.read(connectivityStreamProvider).asData?.value;
    final hasNetwork =
        connectivity != null &&
        connectivity.any((r) => r != ConnectivityResult.none);

    // If device has no network, we can't be online
    if (!hasNetwork) {
      if (!_disposed && state != false) state = false;
      return;
    }

    try {
      // The updated Welcoming and Health Check API is served at the base url
      await _dio.get(apiBaseUrl);
      if (!_disposed) state = true;
    } catch (e) {
      if (e is DioException) {
        // As long as we get a response (even 401, 404, 500, etc), the server is reachable
        if (e.response != null) {
          if (!_disposed && state != true) state = true;
          return;
        }
      }
      if (!_disposed && state != false) state = false;
    }
  }
}

final apiReachabilityProvider = NotifierProvider<ApiReachabilityNotifier, bool>(
  ApiReachabilityNotifier.new,
);

/// True when the device has any active network interface (Wi-Fi, mobile data, etc.).
///
/// This is **independent** of API server reachability — the device can be
/// network-connected while the API is down.
final isNetworkOnlineProvider = Provider<bool>((ref) {
  return ref
      .watch(connectivityStreamProvider)
      .when(
        data: (results) => results.any((r) => r != ConnectivityResult.none),
        loading: () => false,
        error: (_, _) => false,
      );
});

/// Three-state connection status that distinguishes network failures from API
/// failures, enabling the UI to show accurate, distinct notifications.
///
/// - [ConnectionStatus.online]: device has network AND API is reachable.
/// - [ConnectionStatus.networkOffline]: device has no internet connection.
/// - [ConnectionStatus.apiUnreachable]: device is online but the API server
///   cannot be reached.
enum ConnectionStatus { online, networkOffline, apiUnreachable }

/// Provides a granular [ConnectionStatus] derived from both network and API
/// reachability states.
final connectionStatusProvider = Provider<ConnectionStatus>((ref) {
  final hasNetwork = ref.watch(isNetworkOnlineProvider);
  if (!hasNetwork) return ConnectionStatus.networkOffline;
  final apiReachable = ref.watch(apiReachabilityProvider);
  return apiReachable
      ? ConnectionStatus.online
      : ConnectionStatus.apiUnreachable;
});

/// A simple bool that is `true` only when both the device has network AND the
/// API server is reachable.
///
/// Use [isNetworkOnlineProvider] for raw network state, or
/// [connectionStatusProvider] for the full three-state view.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectionStatusProvider) == ConnectionStatus.online;
});
