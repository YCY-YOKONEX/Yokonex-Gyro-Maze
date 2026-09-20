import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// UI 使用 0-180，设备协议使用 0-276。
class IntensityMapper {
  static const int uiMin = 0;
  static const int uiMax = 180;
  static const int deviceMin = 0;
  static const int deviceMax = 276;

  static int uiToDevice(num value) {
    final uiValue = value.round().clamp(uiMin, uiMax);
    return (uiValue * deviceMax / uiMax).round().clamp(deviceMin, deviceMax);
  }

  static int deviceToUi(num value) {
    final deviceValue = value.round().clamp(deviceMin, deviceMax);
    return (deviceValue * uiMax / deviceMax).round().clamp(uiMin, uiMax);
  }
}

enum BleDeviceGeneration { v1, v2 }

class BleOutput {
  const BleOutput({
    required this.uiIntensity,
    required this.frequency,
    required this.pulseWidth,
  });

  final int uiIntensity;
  final int frequency;
  final int pulseWidth;
}

/// YYC-DJ 两代设备共用的 BLE 数据包编码。
class BleProtocol {
  static final serviceUuid = Guid('0000FF30-0000-1000-8000-00805F9B34FB');
  static final writeCharacteristicUuid =
      Guid('0000FF31-0000-1000-8000-00805F9B34FB');
  static final notifyCharacteristicUuid =
      Guid('0000FF32-0000-1000-8000-00805F9B34FB');

  static List<int> encode(BleDeviceGeneration generation, BleOutput output) {
    final deviceIntensity = IntensityMapper.uiToDevice(output.uiIntensity);
    final frequency = output.frequency.clamp(1, 100);
    final pulseWidth = output.pulseWidth.clamp(0, 100);
    switch (generation) {
      case BleDeviceGeneration.v1:
        return _withChecksum([
          0x35,
          0x11,
          0x03, // A/B 同步频道
          deviceIntensity == 0 ? 0x00 : 0x01,
          deviceIntensity >> 8,
          deviceIntensity & 0xff,
          0x11, // V1.6 自定义模式
          frequency,
          pulseWidth,
        ]);
      case BleDeviceGeneration.v2:
        return _withChecksum([
          0x35,
          0x11,
          0x02, // V2.0 实时模式
          deviceIntensity >> 8,
          deviceIntensity & 0xff,
          frequency,
          pulseWidth,
          deviceIntensity >> 8,
          deviceIntensity & 0xff,
          frequency,
          pulseWidth,
        ]);
    }
  }

  /// 设备主动上报时，读取包内第一个强度高低字节并转换成 UI 强度。
  static int? parseReportedUiIntensity(
    BleDeviceGeneration generation,
    List<int> packet,
  ) {
    if (packet.length < (generation == BleDeviceGeneration.v1 ? 6 : 5)) {
      return null;
    }
    final highIndex = generation == BleDeviceGeneration.v1 ? 4 : 3;
    if (packet.length <= highIndex + 1) return null;
    final deviceValue =
        ((packet[highIndex] & 0xff) << 8) | (packet[highIndex + 1] & 0xff);
    return IntensityMapper.deviceToUi(deviceValue);
  }

  static List<int> _withChecksum(List<int> payload) {
    final checksum = payload.fold<int>(0, (sum, byte) => sum + byte) & 0xff;
    return [...payload, checksum];
  }
}
