import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_device_model.dart';
import 'ble_output_port.dart';
import 'ble_permission_service.dart';
import 'ble_protocol.dart';

enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error
}

/// BLE 扫描、连接、特征发现和急停统一入口。
class BleConnectionService implements BleOutputPort {
  final ValueNotifier<BleConnectionStatus> status =
      ValueNotifier(BleConnectionStatus.disconnected);
  final ValueNotifier<BleDeviceInfo?> connectedDevice = ValueNotifier(null);
  final ValueNotifier<int?> reportedUiIntensity = ValueNotifier(null);
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  bool _writing = false;

  @override
  bool get isConnected => status.value == BleConnectionStatus.connected;

  Future<List<BleDeviceInfo>> scan(
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (!await FlutterBluePlus.isSupported) {
      throw StateError('当前设备不支持蓝牙低功耗。');
    }
    await BlePermissionService.ensureGranted();
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      // Android 可以直接拉起系统蓝牙开关；iOS 必须让用户手动开启。
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {
        // iOS 或系统限制下 turnOn 会失败，下面给出统一提示。
      }
      await FlutterBluePlus.adapterState
          .firstWhere((state) => state == BluetoothAdapterState.on)
          .timeout(const Duration(seconds: 5),
              onTimeout: () => throw StateError('请先打开蓝牙后再扫描设备。'));
    }
    final wasConnected = isConnected && connectedDevice.value != null;
    if (!wasConnected) status.value = BleConnectionStatus.scanning;
    errorMessage.value = null;
    final found = <String, BleDeviceInfo>{};
    StreamSubscription<List<ScanResult>>? scanSubscription;
    try {
      // onScanResults 不会重放上一次扫描的缓存，避免已关机的一代设备残留在列表中。
      scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
        for (final result in results) {
          final info = BleDeviceInfo.fromScanResult(result);
          if (info != null) found[info.id] = info;
        }
      });
      // 不使用名称过滤：一代部分固件的本地名称只出现在 platformName，
      // 过滤器会在 Android 扫描阶段直接丢弃这些广播。
      await FlutterBluePlus.startScan(timeout: timeout);
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
      return found.values.toList(growable: false);
    } catch (error) {
      status.value = BleConnectionStatus.error;
      errorMessage.value = error.toString();
      rethrow;
    } finally {
      await scanSubscription?.cancel();
      if (wasConnected && connectedDevice.value != null) {
        status.value = BleConnectionStatus.connected;
      } else if (!isConnected) {
        status.value = BleConnectionStatus.disconnected;
      }
    }
  }

  Future<void> connect(BleDeviceInfo info) async {
    await disconnect();
    status.value = BleConnectionStatus.connecting;
    errorMessage.value = null;
    try {
      await info.device.connect(timeout: const Duration(seconds: 20));
      final services = await info.device.discoverServices();
      final service = services.cast<BluetoothService?>().firstWhere(
            (candidate) => candidate?.uuid == BleProtocol.serviceUuid,
            orElse: () => null,
          );
      if (service == null) {
        throw StateError('设备未找到 FF30 服务。');
      }
      _writeCharacteristic =
          service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
                (characteristic) =>
                    characteristic?.uuid == BleProtocol.writeCharacteristicUuid,
                orElse: () => null,
              );
      _notifyCharacteristic = service.characteristics
          .cast<BluetoothCharacteristic?>()
          .firstWhere(
            (characteristic) =>
                characteristic?.uuid == BleProtocol.notifyCharacteristicUuid,
            orElse: () => null,
          );
      if (_writeCharacteristic == null) {
        throw StateError('设备未找到 FF31 写特征。');
      }
      final notify = _notifyCharacteristic;
      if (notify != null) {
        await notify.setNotifyValue(true);
        _notificationSubscription = notify.onValueReceived.listen((value) {
          reportedUiIntensity.value = BleProtocol.parseReportedUiIntensity(
            info.generation,
            value,
          );
        });
      }
      _connectionSubscription = info.device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _clearConnectionState();
        }
      });
      connectedDevice.value = info;
      status.value = BleConnectionStatus.connected;
      // 连接后先写 0，防止设备保留上一次输出。
      await sendOutput(
          const BleOutput(uiIntensity: 0, frequency: 1, pulseWidth: 50));
    } catch (error) {
      await info.device.disconnect(queue: false).catchError((_) {});
      _clearConnectionState();
      status.value = BleConnectionStatus.error;
      errorMessage.value = error.toString();
      rethrow;
    }
  }

  @override
  Future<void> sendOutput(BleOutput output) async {
    final characteristic = _writeCharacteristic;
    final info = connectedDevice.value;
    if (characteristic == null || info == null || !isConnected) {
      throw StateError('设备未连接，不能发送输出。');
    }
    // 串行写入，避免 100ms 刷新时出现 BLE 操作交叠。
    while (_writing) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    _writing = true;
    try {
      await characteristic.write(
        BleProtocol.encode(info.generation, output),
        // 实时碰墙输出优先使用无响应写，避免每次等待设备 ACK。
        withoutResponse: characteristic.properties.writeWithoutResponse,
      );
    } finally {
      _writing = false;
    }
  }

  Future<void> stopOutput() async {
    if (!isConnected) return;
    try {
      await sendOutput(
          const BleOutput(uiIntensity: 0, frequency: 1, pulseWidth: 50));
    } catch (error) {
      errorMessage.value = error.toString();
    }
  }

  Future<void> disconnect() async {
    final info = connectedDevice.value;
    await stopOutput();
    await _notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _notificationSubscription = null;
    _connectionSubscription = null;
    if (info != null && !info.device.isDisconnected) {
      await info.device.disconnect().catchError((_) {});
    }
    _clearConnectionState();
  }

  Future<void> dispose() async {
    await disconnect();
    status.dispose();
    connectedDevice.dispose();
    reportedUiIntensity.dispose();
    errorMessage.dispose();
  }

  void _clearConnectionState() {
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    connectedDevice.value = null;
    reportedUiIntensity.value = null;
    if (status.value != BleConnectionStatus.error) {
      status.value = BleConnectionStatus.disconnected;
    }
  }
}
