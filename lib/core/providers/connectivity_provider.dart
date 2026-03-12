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

class ApiReachabilityNotifier extends StateNotifier<bool> {
  ApiReachabilityNotifier(this.ref) : super(false) {
    _init();
  }

  final Ref ref;
  Timer? _timer;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  void _init() {
    // Ping immediately
    _ping();
    // Then every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _ping());
  }

  Future<void> _ping() async {
    final connectivity = ref.read(connectivityStreamProvider).valueOrNull;
    final hasNetwork = connectivity != null && connectivity.any((r) => r != ConnectivityResult.none);
    
    // If device has no network, we can\'t be online
    if (!hasNetwork) {
      if (mounted && state != false) state = false;
      return;
    }

    try {
      // We append /test if the base url doesn\'t already end with it, just in case
      final url = apiBaseUrl.endsWith('/test') ? apiBaseUrl : '$apiBaseUrl/test';
      await _dio.get(url);
      if (mounted) state = true;
    } catch (e) {
      if (e is DioException) {
        // As long as we get a response (even 401, 404, 500, etc), the server is reachable
        if (e.response != null) {
          if (mounted && state != true) state = true;
          return;
        }
      }
      if (mounted && state != false) state = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final apiReachabilityProvider = StateNotifierProvider<ApiReachabilityNotifier, bool>(
  (ref) => ApiReachabilityNotifier(ref),
);

/// A simple bool that is `true` when any non-none connectivity exists
/// AND the API server is reachable.
final isOnlineProvider = Provider<bool>((ref) {
  final hasNetwork = ref.watch(connectivityStreamProvider).when(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    loading: () => false,
    error: (_, __) => false,
  );
  
  if (!hasNetwork) return false;
  
  // Also check reachability
  return ref.watch(apiReachabilityProvider);
});
