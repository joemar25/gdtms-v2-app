import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geolocator;

/// Manages periodic background location pings to the server.
///
/// The service owns a single [Timer] that fires every [kPingInterval].
/// It is intentionally stateless about the API call — the caller supplies
/// an [onPing] callback that receives the captured [Position] and is
/// responsible for the HTTP POST.  This keeps the service testable and
/// decoupled from Riverpod / ApiClient.
///
/// Usage (from [_AutoSyncListenerState] in app.dart):
/// ```dart
/// _locationPing.start(_sendLocationPing);   // starts timer + immediate ping
/// _locationPing.stop();                     // cancels timer
/// ```
class LocationPingService {
  LocationPingService._();

  static final LocationPingService instance = LocationPingService._();

  /// How often to send a background location update while online.
  static const kPingInterval = Duration(seconds: 60);

  Timer? _timer;

  bool get isRunning => _timer != null && _timer!.isActive;

  /// Starts the periodic ping timer and fires an immediate first ping.
  /// Cancels any existing timer before creating a new one.
  void start(Future<void> Function(geolocator.Position) onPing) {
    stop();
    _firePing(onPing); // immediate first ping on start
    _timer = Timer.periodic(kPingInterval, (_) => _firePing(onPing));
  }

  /// Cancels the periodic timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _firePing(
    Future<void> Function(geolocator.Position) onPing,
  ) async {
    try {
      final serviceEnabled =
          await geolocator.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await geolocator.Geolocator.checkPermission();
      if (permission == geolocator.LocationPermission.denied ||
          permission == geolocator.LocationPermission.deniedForever) {
        return;
      }

      final position = await geolocator.Geolocator.getCurrentPosition(
        locationSettings: const geolocator.LocationSettings(
          accuracy: geolocator.LocationAccuracy.medium,
        ),
      );

      await onPing(position);
    } catch (e) {
      // Location pings are best-effort — silently swallow all errors.
      debugPrint('[LOCATION] ping error: $e');
    }
  }
}
