import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_protocol.dart';

class BleDeviceInfo {
  const BleDeviceInfo({
    required this.device,
    required this.name,
    required this.generation,
    this.rssi,
  });

  final BluetoothDevice device;
  final String name;
  final BleDeviceGeneration generation;
  final int? rssi;

  String get id => device.remoteId.str;

  String get generationLabel =>
      generation == BleDeviceGeneration.v2 ? '二代' : '一代';

  String get displayName => '$name（$generationLabel）';

  static BleDeviceInfo? fromScanResult(ScanResult result) {
    final name = _firstNonEmpty([
      result.advertisementData.advName,
      result.device.advName,
      result.device.platformName,
    ]);
    final generation = generationFromName(name) ??
        _generationFromServiceAdvertisement(result.advertisementData);
    if (generation == null) return null;
    return BleDeviceInfo(
      device: result.device,
      // 一代部分固件只广播服务 UUID，不广播本地名称，给它一个可识别的连接名。
      name: name.isEmpty ? 'YYC-DJ' : name,
      generation: generation,
      rssi: result.rssi,
    );
  }

  static BleDeviceGeneration? generationFromName(String name) {
    final normalized = name.trim().toUpperCase();
    final compact = normalized.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.contains('YYCDJV2') ||
        (compact.contains('YYCDJ') && compact.contains('V2'))) {
      return BleDeviceGeneration.v2;
    }
    if (compact.contains('YYCDJ')) {
      return BleDeviceGeneration.v1;
    }
    return null;
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static BleDeviceGeneration? _generationFromServiceAdvertisement(
    AdvertisementData advertisement,
  ) {
    final hasYycService = advertisement.serviceUuids.any(
      (uuid) => uuid.str == BleProtocol.serviceUuid.str,
    );
    // 老设备有些固件不广播名称，只能先按一代协议尝试连接。
    return hasYycService ? BleDeviceGeneration.v1 : null;
  }
}
