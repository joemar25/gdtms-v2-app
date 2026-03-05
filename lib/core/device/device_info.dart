import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/config.dart';

final deviceInfoProvider = Provider<DeviceInfoService>((ref) => DeviceInfoService());

class DeviceInfoService {
  String get os => Platform.isAndroid ? 'android' : 'ios';

  Future<String> get deviceModel async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return '${info.manufacturer} ${info.model}';
    }
    final info = await plugin.iosInfo;
    return info.utsname.machine;
  }

  Future<String> get deviceId async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return info.id;
    }
    final info = await plugin.iosInfo;
    return info.identifierForVendor ?? 'unknown';
  }

  Future<String> get osVersion async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return 'Android ${info.version.release} (API ${info.version.sdkInt})';
    }
    final info = await plugin.iosInfo;
    return 'iOS ${info.systemVersion}';
  }

  Future<String> get sdkVersion async {
    final dartVer = Platform.version.split(' ').first;
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return 'Dart $dartVer \u00b7 API ${info.version.sdkInt}';
    }
    final info = await plugin.iosInfo;
    return 'Dart $dartVer \u00b7 iOS ${info.systemVersion}';
  }

  Future<Map<String, dynamic>> toMap() async => {
        'os': os,
        'app_version': appVersion,
        'device_model': await deviceModel,
        'device_id': await deviceId,
      };
}
