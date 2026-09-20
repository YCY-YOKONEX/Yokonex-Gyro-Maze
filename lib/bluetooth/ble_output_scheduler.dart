import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ble_output_port.dart';
import 'ble_protocol.dart';

/// 以 100ms 节流发送墙体接触输出，离墙时立即发送 0。
class BleOutputScheduler {
  BleOutputScheduler({required this.service, this.onError});

  final BleOutputPort service;
  final void Function(Object error)? onError;

  static const refreshPeriod = Duration(milliseconds: 100);
  static const rampDuration = Duration(seconds: 2);

  /// 当前真正请求发送给设备的界面强度，供 HUD 显示。
  final ValueNotifier<int> currentUiIntensity = ValueNotifier(0);

  Duration _sinceLastSend = Duration.zero;
  bool _contacting = false;
  bool _stopped = true;
  BleOutput? _queuedOutput;
  bool _writing = false;

  void tick({
    required Duration delta,
    required Duration contactDuration,
    required int maxUiIntensity,
    required bool enabled,
  }) {
    if (!enabled || !service.isConnected) {
      if (_contacting || !_stopped) unawaited(stop());
      return;
    }
    if (contactDuration <= Duration.zero) {
      if (_contacting || !_stopped) unawaited(stop());
      return;
    }
    _contacting = true;
    _sinceLastSend += delta;
    if (!_stopped && _sinceLastSend < refreshPeriod) return;
    _sinceLastSend = Duration.zero;
    final progress =
        (contactDuration.inMicroseconds / rampDuration.inMicroseconds)
            .clamp(0.0, 1.0)
            .toDouble();
    final uiIntensity =
        (maxUiIntensity.clamp(0, IntensityMapper.uiMax) * progress).round();
    final output = BleOutput(
      // 最大强度大于 0 时，第一包也要有有效输出，避免设备看起来没有反应。
      uiIntensity: maxUiIntensity > 0 && uiIntensity == 0 ? 1 : uiIntensity,
      frequency: 1 + (99 * progress).round(),
      pulseWidth: 50,
    );
    _stopped = false;
    _enqueue(output);
  }

  Future<void> stop() async {
    _sinceLastSend = Duration.zero;
    _contacting = false;
    _stopped = true;
    currentUiIntensity.value = 0;
    if (!service.isConnected) {
      _queuedOutput = null;
      return;
    }
    _enqueue(const BleOutput(uiIntensity: 0, frequency: 1, pulseWidth: 50));
  }

  Future<void> dispose() async {
    await stop();
    currentUiIntensity.dispose();
  }

  /// 写入期间只替换待发送命令，完成后立即发送最新的一条。
  /// 这样快速离墙再碰墙时，旧的停止命令不会覆盖新的输出。
  void _enqueue(BleOutput output) {
    _queuedOutput = output;
    unawaited(_drainQueue());
  }

  Future<void> _drainQueue() async {
    if (_writing) return;
    _writing = true;
    try {
      while (_queuedOutput != null) {
        final output = _queuedOutput!;
        _queuedOutput = null;
        currentUiIntensity.value = output.uiIntensity;
        try {
          await service.sendOutput(output);
        } catch (error) {
          _queuedOutput = null;
          _contacting = false;
          _stopped = true;
          currentUiIntensity.value = 0;
          onError?.call(error);
          break;
        }
      }
    } finally {
      _writing = false;
      // tick/stop 可能在 finally 前排入了新命令。
      if (_queuedOutput != null) unawaited(_drainQueue());
    }
  }
}
