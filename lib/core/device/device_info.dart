import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';

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

  Future<Map<String, dynamic>> toMap() async => {
        'os': os,
        'app_version': appVersion,
        'device_model': await deviceModel,
        'device_id': await deviceId,
      };
}
