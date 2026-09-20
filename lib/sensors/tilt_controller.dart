import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

enum InputMode { tilt, touch }

enum TiltOrientation { portrait, landscapeLeft, landscapeRight }

/// 统一处理传感器坐标、校准、死区和简单互补滤波。
class TiltController {
  final ValueNotifier<InputMode> inputMode = ValueNotifier(InputMode.tilt);
  final ValueNotifier<bool> sensorAvailable = ValueNotifier(false);

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  Offset _fused = Offset.zero;
  Offset _calibration = Offset.zero;
  Offset _touch = Offset.zero;
  DateTime? _lastGyroscopeTime;
  TiltOrientation _orientation = TiltOrientation.portrait;

  Offset get input {
    if (inputMode.value == InputMode.touch) return _touch;
    final calibrated = _fused - _calibration;
    final clean = _applyDeadZone(calibrated);
    // 设备倾斜方向与迷宫坐标方向相反，统一在输入层反向。
    return Offset(
      (-clean.dx * 1.55).clamp(-1.0, 1.0).toDouble(),
      (-clean.dy * 1.55).clamp(-1.0, 1.0).toDouble(),
    );
  }

  Future<void> start() async {
    try {
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(_onAccelerometer, onError: _onSensorError);
      _gyroscopeSubscription = gyroscopeEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(_onGyroscope, onError: _onSensorError);
      sensorAvailable.value = true;
    } on Object {
      _onSensorError(null);
    }
  }

  void calibrate() {
    _calibration = _fused;
  }

  void setOrientation(TiltOrientation orientation) {
    if (_orientation == orientation) return;
    _orientation = orientation;
    // 旋转后旧校准值不再对应当前轴，立即重新以当前姿态为基准。
    calibrate();
  }

  void setInputMode(InputMode mode) {
    inputMode.value = mode;
    if (mode == InputMode.tilt) calibrate();
  }

  void setTouchInput(Offset value) {
    _touch = Offset(
      value.dx.clamp(-1.0, 1.0).toDouble(),
      value.dy.clamp(-1.0, 1.0).toDouble(),
    );
  }

  void stopTouch() {
    _touch = Offset.zero;
  }

  void dispose() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    inputMode.dispose();
    sensorAvailable.dispose();
  }

  void _onAccelerometer(AccelerometerEvent event) {
    // 使用向量长度归一化，避免斜着拿手机时把倾斜量错误压小。
    final gravity = math
        .max(
            math.sqrt(
                event.x * event.x + event.y * event.y + event.z * event.z),
            0.001)
        .toDouble();
    final rawTarget = Offset(
      (event.x / gravity).clamp(-1.0, 1.0).toDouble(),
      (-event.y / gravity).clamp(-1.0, 1.0).toDouble(),
    );
    final target = switch (_orientation) {
      TiltOrientation.portrait => rawTarget,
      TiltOrientation.landscapeLeft => Offset(-rawTarget.dy, rawTarget.dx),
      TiltOrientation.landscapeRight => Offset(rawTarget.dy, -rawTarget.dx),
    };
    // 提高重力校正比例，让小幅倾斜更快反映到滚珠，同时保留陀螺仪的短时响应。
    _fused = Offset(
      _fused.dx * 0.84 + target.dx * 0.16,
      _fused.dy * 0.84 + target.dy * 0.16,
    );
  }

  void _onGyroscope(GyroscopeEvent event) {
    final now = DateTime.now();
    final previous = _lastGyroscopeTime;
    _lastGyroscopeTime = now;
    if (previous == null) return;
    final dt = now.difference(previous).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (dt <= 0 || dt > 0.2) return;

    final gyro = Offset(
      (event.x * dt).clamp(-0.08, 0.08).toDouble(),
      (-event.y * dt).clamp(-0.08, 0.08).toDouble(),
    );
    _fused = Offset(
      (_fused.dx + gyro.dx).clamp(-1.25, 1.25).toDouble(),
      (_fused.dy + gyro.dy).clamp(-1.25, 1.25).toDouble(),
    );
  }

  void _onSensorError(Object? error) {
    sensorAvailable.value = false;
    inputMode.value = InputMode.touch;
  }

  Offset _applyDeadZone(Offset value) {
    const deadZone = 0.04;
    double clean(double axis) {
      if (axis.abs() < deadZone) return 0;
      final sign = axis.sign;
      return sign *
          ((axis.abs() - deadZone) / (1 - deadZone)).clamp(0.0, 1.0).toDouble();
    }

    return Offset(clean(value.dx), clean(value.dy));
  }
}
