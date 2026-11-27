import 'package:flutter/services.dart';

class DeviceBatteryService {
  static const MethodChannel _channel = MethodChannel(
    'rideguardian/device_battery',
  );

  Future<int?> getLevel() async {
    try {
      final level = await _channel.invokeMethod<int>('getBatteryLevel');
      if (level == null || level < 0 || level > 100) return null;
      return level;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
