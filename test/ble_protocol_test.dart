import 'package:flutter_test/flutter_test.dart';

import 'package:gyro_maze/bluetooth/ble_device_model.dart';
import 'package:gyro_maze/bluetooth/ble_protocol.dart';

void main() {
  group('IntensityMapper', () {
    test('maps UI 0-180 to device 0-276', () {
      expect(IntensityMapper.uiToDevice(0), 0);
      expect(IntensityMapper.uiToDevice(90), 138);
      expect(IntensityMapper.uiToDevice(180), 276);
    });

    test('clamps UI and device input at both boundaries', () {
      expect(IntensityMapper.uiToDevice(-20), 0);
      expect(IntensityMapper.uiToDevice(200), 276);
      expect(IntensityMapper.deviceToUi(-1), 0);
      expect(IntensityMapper.deviceToUi(300), 180);
    });

    test('converts device intensity back to UI intensity', () {
      expect(IntensityMapper.deviceToUi(0), 0);
      expect(IntensityMapper.deviceToUi(138), 90);
      expect(IntensityMapper.deviceToUi(276), 180);
    });
  });

  group('BleProtocol', () {
    test('encodes V1 intensity and checksum', () {
      final packet = BleProtocol.encode(
        BleDeviceGeneration.v1,
        const BleOutput(uiIntensity: 90, frequency: 1, pulseWidth: 50),
      );
      expect(
          packet, [0x35, 0x11, 0x03, 0x01, 0x00, 0x8a, 0x11, 0x01, 0x32, 0x18]);
      expect(
          packet.last,
          packet
              .sublist(0, packet.length - 1)
              .fold<int>(0, (sum, byte) => (sum + byte) & 0xff));
    });

    test('encodes V2 A/B channels with the same intensity', () {
      final packet = BleProtocol.encode(
        BleDeviceGeneration.v2,
        const BleOutput(uiIntensity: 180, frequency: 100, pulseWidth: 50),
      );
      expect(packet, [
        0x35,
        0x11,
        0x02,
        0x01,
        0x14,
        0x64,
        0x32,
        0x01,
        0x14,
        0x64,
        0x32,
        0x9e
      ]);
      expect(packet[3], packet[7]);
      expect(packet[4], packet[8]);
      expect(
          packet.last,
          packet
              .sublist(0, packet.length - 1)
              .fold<int>(0, (sum, byte) => (sum + byte) & 0xff));
    });

    test('recognizes exact generation names', () {
      expect(
          BleDeviceInfo.generationFromName('YYC-DJ'), BleDeviceGeneration.v1);
      expect(BleDeviceInfo.generationFromName('YYC-DJ-V2'),
          BleDeviceGeneration.v2);
      expect(
          BleDeviceInfo.generationFromName('YYC_DJ_1'), BleDeviceGeneration.v1);
      expect(BleDeviceInfo.generationFromName('YYC DJ V2'),
          BleDeviceGeneration.v2);
      expect(BleDeviceInfo.generationFromName('other-device'), isNull);
    });
  });
}
