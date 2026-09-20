import 'dart:io';

import 'package:flutter/services.dart';

/// Android 12+ 的 BLE 权限由原生层统一申请；iOS 由 CoreBluetooth 在首次扫描时提示。
class BlePermissionService {
  static const _channel = MethodChannel('gyro_maze/ble_permissions');

  static Future<void> ensureGranted() async {
    if (!Platform.isAndroid) return;
    try {
      final result = await _channel.invokeMethod<Object?>('request');
      final granted = result is Map && result['granted'] == true;
      final permanentlyDenied =
          result is Map && result['permanentlyDenied'] == true;
      if (granted) return;
      if (permanentlyDenied) {
        throw StateError('蓝牙权限被永久拒绝，请在系统设置中允许附近设备权限。');
      }
      throw StateError('需要允许附近设备权限才能扫描 YYC-DJ。');
    } on MissingPluginException {
      // 非 Android 平台或旧安装包没有原生通道时交给 flutter_blue_plus 处理。
      if (Platform.isAndroid) rethrow;
    }
  }

  static Future<void> openSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openSettings');
  }
}
