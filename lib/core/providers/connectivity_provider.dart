import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams the list of active [ConnectivityResult] values whenever the
/// network state changes.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

/// A simple bool that is `true` when any non-none connectivity exists.
/// Defaults to `false` while the stream is loading to support offline cold
/// start — the stream updates to `true` within ~200ms if actually online.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityStreamProvider).when(
    data: (results) => results.any((r) => r != ConnectivityResult.none),
    loading: () => false,
    error: (_, __) => false,
  );
});
