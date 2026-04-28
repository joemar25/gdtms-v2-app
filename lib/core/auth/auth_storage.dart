// DOCS: docs/development-standards.md
// DOCS: docs/core/auth.md — update that file when you edit this one.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _tokenKey = 'courier_token';
const _courierKey = 'courier_data';
const _deviceIdKey = 'device_id';
const _courierIdKey = 'last_courier_id';
const _initialSyncKey = 'initial_sync_completed';
const _pendingFcmKey = 'pending_fcm_token';
const _lastSyncedFcmKey = 'last_synced_fcm_token';

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

class AuthStorage {
  AuthStorage({FlutterSecureStorage? secureStorage})
    : _storage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> setToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> setCourier(Map<String, dynamic> courier) {
    return _storage.write(key: _courierKey, value: jsonEncode(courier));
  }

  Future<Map<String, dynamic>?> getCourier() async {
    try {
      final raw = await _storage.read(key: _courierKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore malformed persisted courier payload and continue as logged-out.
    }
    return null;
  }

  Future<String> getDeviceId() async {
    String? deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    return deviceId;
  }

  Future<void> setLastCourierId(String courierId) =>
      _storage.write(key: _courierIdKey, value: courierId);

  Future<String?> getLastCourierId() => _storage.read(key: _courierIdKey);

  Future<void> setLastSyncTime(int timestampMs) =>
      _storage.write(key: 'last_sync_time', value: timestampMs.toString());

  Future<int?> getLastSyncTime() async {
    final val = await _storage.read(key: 'last_sync_time');
    if (val == null) return null;
    return int.tryParse(val);
  }

  Future<bool> isInitialSyncCompleted() async {
    final val = await _storage.read(key: _initialSyncKey);
    return val == 'true';
  }

  Future<void> setInitialSyncCompleted(bool completed) =>
      _storage.write(key: _initialSyncKey, value: completed.toString());

  Future<void> clearAll() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _courierKey);
    await _storage.delete(key: _initialSyncKey);
    await _storage.delete(key: _pendingFcmKey);
    await _storage.delete(key: _lastSyncedFcmKey);
  }

  // --- FCM token persistence for offline-safe syncing ---------------------
  Future<void> setPendingFcmToken(String? token) {
    final jsonVal = jsonEncode(token);
    return _storage.write(key: _pendingFcmKey, value: jsonVal);
  }

  Future<bool> hasPendingFcmToken() async {
    final raw = await _storage.read(key: _pendingFcmKey);
    return raw != null;
  }

  Future<String?> getPendingFcmToken() async {
    final raw = await _storage.read(key: _pendingFcmKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded == null) return null;
    return decoded.toString();
  }

  Future<void> clearPendingFcmToken() async {
    await _storage.delete(key: _pendingFcmKey);
  }

  Future<void> setLastSyncedFcmToken(String? token) async {
    await _storage.write(key: _lastSyncedFcmKey, value: jsonEncode(token));
  }

  Future<String?> getLastSyncedFcmToken() async {
    final raw = await _storage.read(key: _lastSyncedFcmKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded == null) return null;
    return decoded.toString();
  }
}
