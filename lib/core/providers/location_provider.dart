import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' hide ServiceStatus;

enum LocationStatus {
  determining,
  ready,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
}

class LocationState {
  const LocationState({
    this.status = LocationStatus.determining,
    this.isServiceEnabled = false,
    this.permissionStatus = PermissionStatus.denied,
  });

  final LocationStatus status;
  final bool isServiceEnabled;
  final PermissionStatus permissionStatus;

  bool get isReady => status == LocationStatus.ready;

  LocationState copyWith({
    LocationStatus? status,
    bool? isServiceEnabled,
    PermissionStatus? permissionStatus,
  }) {
    return LocationState(
      status: status ?? this.status,
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      permissionStatus: permissionStatus ?? this.permissionStatus,
    );
  }
}

class LocationProviderNotifier extends StateNotifier<LocationState>
    with WidgetsBindingObserver {
  LocationProviderNotifier() : super(const LocationState()) {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions and service status when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _init() async {
    // Listen to GPS hardware toggle (user turns Location on/off in quick settings)
    _serviceStatusSubscription =
        Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      _checkStatus();
    });

    await _checkStatus();
  }

  Future<void> _checkStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Permission.location.status;

    LocationStatus currentStatus;

    if (!serviceEnabled) {
      currentStatus = LocationStatus.serviceDisabled;
    } else if (permission.isPermanentlyDenied) {
      currentStatus = LocationStatus.permissionPermanentlyDenied;
    } else if (permission.isDenied || permission.isRestricted) {
      currentStatus = LocationStatus.permissionDenied;
    } else {
      currentStatus = LocationStatus.ready;
    }

    state = state.copyWith(
      status: currentStatus,
      isServiceEnabled: serviceEnabled,
      permissionStatus: permission,
    );
  }

  Future<void> requestPermission() async {
    await Permission.location.request();
    await _checkStatus();
  }

  Future<void> openSettings() async {
    if (state.status == LocationStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await openAppSettings();
    }
  }
  
  // Method to manually force a re-check from the UI.
  Future<void> refresh() async {
    state = state.copyWith(status: LocationStatus.determining);
    await _checkStatus();
  }
}

final locationProvider =
    StateNotifierProvider<LocationProviderNotifier, LocationState>((ref) {
  return LocationProviderNotifier();
});
