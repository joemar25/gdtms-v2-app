// DOCS: docs/core/providers.md — update that file when you edit this one.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum ExtraPermissionStatus {
  determining,
  cameraPermissionDenied,
  cameraPermissionPermanentlyDenied,
  notificationPermissionDenied,
  notificationPermissionPermanentlyDenied,
  ready,
}

class ExtraPermissionsState {
  const ExtraPermissionsState({
    this.status = ExtraPermissionStatus.determining,
    this.cameraStatus = PermissionStatus.denied,
    this.notificationStatus = PermissionStatus.denied,
  });

  final ExtraPermissionStatus status;
  final PermissionStatus cameraStatus;
  final PermissionStatus notificationStatus;

  bool get isReady => status == ExtraPermissionStatus.ready;

  ExtraPermissionsState copyWith({
    ExtraPermissionStatus? status,
    PermissionStatus? cameraStatus,
    PermissionStatus? notificationStatus,
  }) {
    return ExtraPermissionsState(
      status: status ?? this.status,
      cameraStatus: cameraStatus ?? this.cameraStatus,
      notificationStatus: notificationStatus ?? this.notificationStatus,
    );
  }
}

class ExtraPermissionsNotifier extends Notifier<ExtraPermissionsState>
    with WidgetsBindingObserver {
  bool _disposed = false;

  @override
  ExtraPermissionsState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _disposed = true;
      WidgetsBinding.instance.removeObserver(this);
    });
    _checkStatus();
    return const ExtraPermissionsState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    final camera = await Permission.camera.status;
    final notification = await Permission.notification.status;

    ExtraPermissionStatus current;

    if (camera.isPermanentlyDenied) {
      current = ExtraPermissionStatus.cameraPermissionPermanentlyDenied;
    } else if (camera.isDenied || camera.isRestricted) {
      current = ExtraPermissionStatus.cameraPermissionDenied;
    } else if (notification.isPermanentlyDenied) {
      current = ExtraPermissionStatus.notificationPermissionPermanentlyDenied;
    } else if (notification.isDenied || notification.isRestricted) {
      current = ExtraPermissionStatus.notificationPermissionDenied;
    } else {
      current = ExtraPermissionStatus.ready;
    }

    if (!_disposed) {
      state = state.copyWith(
        status: current,
        cameraStatus: camera,
        notificationStatus: notification,
      );
    }
  }

  Future<void> requestCamera() async {
    await Permission.camera.request();
    await _checkStatus();
  }

  Future<void> requestNotification() async {
    // Request via permission_handler (Android 13+).
    await Permission.notification.request();
    // Also request via FirebaseMessaging so the FCM token pipeline activates
    // on iOS after the user grants from our screen.
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _checkStatus();
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  Future<void> refresh() async {
    if (!_disposed) {
      state = state.copyWith(status: ExtraPermissionStatus.determining);
    }
    await _checkStatus();
  }
}

final extraPermissionsProvider =
    NotifierProvider<ExtraPermissionsNotifier, ExtraPermissionsState>(
      ExtraPermissionsNotifier.new,
    );
