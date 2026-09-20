import 'package:flutter_test/flutter_test.dart';

import 'package:gyro_maze/bluetooth/ble_output_port.dart';
import 'package:gyro_maze/bluetooth/ble_output_scheduler.dart';
import 'package:gyro_maze/bluetooth/ble_protocol.dart';

class _FakeBleOutputPort implements BleOutputPort {
  @override
  bool isConnected = true;

  final outputs = <BleOutput>[];
  final Duration writeDelay;

  _FakeBleOutputPort({this.writeDelay = Duration.zero});

  @override
  Future<void> sendOutput(BleOutput output) async {
    outputs.add(output);
    if (writeDelay > Duration.zero) await Future<void>.delayed(writeDelay);
  }
}

void main() {
  test('first wall output is non-zero and ramps to the configured maximum',
      () async {
    final port = _FakeBleOutputPort();
    final scheduler = BleOutputScheduler(service: port);

    scheduler.tick(
      delta: const Duration(milliseconds: 16),
      contactDuration: const Duration(milliseconds: 16),
      maxUiIntensity: 180,
      enabled: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(port.outputs.single.uiIntensity, 1);

    scheduler.tick(
      delta: const Duration(milliseconds: 100),
      contactDuration: const Duration(seconds: 1),
      maxUiIntensity: 180,
      enabled: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(port.outputs.last.uiIntensity, 90);

    scheduler.tick(
      delta: const Duration(milliseconds: 100),
      contactDuration: const Duration(seconds: 2),
      maxUiIntensity: 180,
      enabled: true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(port.outputs.last.uiIntensity, 180);

    await scheduler.stop();
    await Future<void>.delayed(Duration.zero);
    expect(port.outputs.last.uiIntensity, 0);
    await scheduler.dispose();
  });

  test('latest output survives an in-flight write', () async {
    final port =
        _FakeBleOutputPort(writeDelay: const Duration(milliseconds: 20));
    final scheduler = BleOutputScheduler(service: port);

    scheduler.tick(
      delta: const Duration(milliseconds: 16),
      contactDuration: const Duration(milliseconds: 16),
      maxUiIntensity: 180,
      enabled: true,
    );
    scheduler.tick(
      delta: const Duration(milliseconds: 100),
      contactDuration: const Duration(milliseconds: 300),
      maxUiIntensity: 180,
      enabled: true,
    );
    await scheduler.stop();
    scheduler.tick(
      delta: const Duration(milliseconds: 100),
      contactDuration: const Duration(milliseconds: 400),
      maxUiIntensity: 180,
      enabled: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(port.outputs.last.uiIntensity, greaterThan(0));
    await scheduler.dispose();
  });
}
