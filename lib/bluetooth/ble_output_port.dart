import 'ble_protocol.dart';

/// BLE 输出端口，便于调度器在测试中使用假设备。
abstract interface class BleOutputPort {
  bool get isConnected;

  Future<void> sendOutput(BleOutput output);
}
