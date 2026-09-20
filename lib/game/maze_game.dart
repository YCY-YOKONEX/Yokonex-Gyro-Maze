import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Alignment, Colors, RadialGradient;

import '../bluetooth/ble_connection_service.dart';
import '../bluetooth/ble_output_scheduler.dart';
import '../sensors/tilt_controller.dart';
import 'ball_physics.dart';
import 'maze_level.dart';
import 'maze_theme.dart';

enum GameStatus { waiting, playing, paused, completed, locked }

/// Flame 只负责游戏循环和画布生命周期，玩法逻辑保持在普通 Dart 类中。
class MazeGame extends FlameGame {
  MazeGame({BleConnectionService? bleService})
      : _level = MazeLevel.first,
        _physics = BallPhysics(level: MazeLevel.first),
        _tilt = TiltController(),
        _bleService = bleService {
    final service = _bleService;
    if (service != null) {
      _bleScheduler = BleOutputScheduler(
        service: service,
        onError: _onBleError,
      );
      _bleScheduler!.currentUiIntensity.addListener(_syncCurrentUiIntensity);
    }
  }

  MazeLevel _level;
  BallPhysics _physics;
  final TiltController _tilt;
  final BleConnectionService? _bleService;
  BleOutputScheduler? _bleScheduler;

  final ValueNotifier<GameStatus> status = ValueNotifier(GameStatus.waiting);
  final ValueNotifier<MazeLevel> level = ValueNotifier(MazeLevel.first);
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);
  final ValueNotifier<InputMode> inputMode = ValueNotifier(InputMode.tilt);
  final ValueNotifier<bool> sensorAvailable = ValueNotifier(false);
  final ValueNotifier<int> currentUiIntensity = ValueNotifier(0);

  Rect _boardRect = Rect.zero;
  double _elapsedSeconds = 0;
  int _maxUiIntensity = 0;
  bool _bleEnabled = false;
  bool _resumeAfterOverlay = false;
  bool _resumeAfterLifecycle = false;

  int get maxUiIntensity => _maxUiIntensity;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _tilt.inputMode.addListener(_syncInputMode);
    _tilt.sensorAvailable.addListener(_syncSensorAvailable);
    _bleService?.status.addListener(_syncBleStatus);
    await _tilt.start();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (status.value != GameStatus.playing) return;

    final safeDelta = dt.clamp(0.0, 0.05).toDouble();
    _elapsedSeconds += safeDelta;
    elapsed.value = Duration(milliseconds: (_elapsedSeconds * 1000).round());
    _physics.update(
      Duration(
          microseconds: (safeDelta * Duration.microsecondsPerSecond).round()),
      _tilt.input,
    );
    _bleScheduler?.tick(
      delta: Duration(
          microseconds: (safeDelta * Duration.microsecondsPerSecond).round()),
      contactDuration: _physics.wallContactDuration,
      maxUiIntensity: _maxUiIntensity,
      enabled: _bleEnabled && status.value == GameStatus.playing,
    );
    if (_physics.reachedGoal()) {
      status.value = GameStatus.completed;
      unawaited(_bleScheduler?.stop());
      pauseEngine();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final width = size.x;
    final height = size.y;
    if (width <= 0 || height <= 0) return;

    final theme = _level.theme;
    canvas.drawColor(theme.background, BlendMode.srcOver);
    final boardSize = math.min(width, height).toDouble() * 0.9;
    final frameLeft = (width - boardSize) / 2;
    final frameTop =
        (height - boardSize) / 2 + math.min(26, height * 0.035).toDouble();
    final tile = boardSize / math.max(_level.columns, _level.rows).toDouble();
    final mazeWidth = tile * _level.columns;
    final mazeHeight = tile * _level.rows;
    final left = frameLeft + (boardSize - mazeWidth) / 2;
    final top = frameTop + (boardSize - mazeHeight) / 2;
    final frameRect = Rect.fromLTWH(frameLeft, frameTop, boardSize, boardSize);
    _boardRect = Rect.fromLTWH(left, top, mazeWidth, mazeHeight);

    // 深空方向用低对比轨道线承托迷宫，不再使用厚重的浮层卡片。
    final orbitCenter = frameRect.center;
    canvas.drawCircle(
      orbitCenter,
      boardSize * 0.57,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = theme.primary.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      orbitCenter,
      boardSize * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = theme.primary.withValues(alpha: 0.07),
    );
    final crosshairPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = theme.primary.withValues(alpha: 0.08);
    canvas.drawLine(
      Offset(frameRect.left - boardSize * 0.08, orbitCenter.dy),
      Offset(frameRect.right + boardSize * 0.08, orbitCenter.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(orbitCenter.dx, frameRect.top - boardSize * 0.08),
      Offset(orbitCenter.dx, frameRect.bottom + boardSize * 0.08),
      crosshairPaint,
    );

    final boardPaint = Paint()..color = theme.board.withValues(alpha: 0.8);
    canvas.drawRect(frameRect, boardPaint);

    for (var row = 0; row < _level.rows; row++) {
      for (var column = 0; column < _level.columns; column++) {
        final cell = _level.cellAt(column, row);
        final rect = Rect.fromLTWH(
          left + column * tile,
          top + row * tile,
          tile,
          tile,
        ).deflate(tile * 0.035);
        final paint = Paint()
          ..color = cell == CellType.wall ? theme.wall : theme.path;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(tile * 0.12)),
          paint,
        );
      }
    }

    _drawGoal(canvas, left, top, tile);
    _drawBall(canvas, left, top, tile);
    canvas.drawRect(
      frameRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = theme.border.withValues(alpha: 0.82),
    );
  }

  void togglePause() {
    if (status.value == GameStatus.completed ||
        status.value == GameStatus.waiting ||
        status.value == GameStatus.locked) {
      return;
    }
    if (status.value == GameStatus.paused) {
      status.value = GameStatus.playing;
      resumeEngine();
    } else {
      status.value = GameStatus.paused;
      unawaited(_bleScheduler?.stop());
      pauseEngine();
    }
  }

  /// 打开设备设置时暂停物理循环，避免切换设备期间继续发送输出。
  void pauseForDeviceSettings() {
    _resumeAfterOverlay = status.value == GameStatus.playing;
    if (status.value == GameStatus.playing) {
      status.value = GameStatus.paused;
      pauseEngine();
    }
    stopBleOutput();
  }

  void resumeAfterDeviceSettings() {
    final shouldResume = _resumeAfterOverlay;
    _resumeAfterOverlay = false;
    if (shouldResume &&
        status.value == GameStatus.paused &&
        (!_bleEnabled || (_bleService?.isConnected ?? false))) {
      status.value = GameStatus.playing;
      resumeEngine();
    }
  }

  /// App 进入后台时只记住“之前正在运行”的状态，后台不恢复 BLE 输出。
  void pauseForAppLifecycle() {
    if (_resumeAfterLifecycle) return;
    _resumeAfterLifecycle = status.value == GameStatus.playing;
    if (_resumeAfterLifecycle) status.value = GameStatus.paused;
    stopBleOutput();
    pauseEngine();
  }

  void resumeAfterAppLifecycle() {
    final shouldResume = _resumeAfterLifecycle;
    _resumeAfterLifecycle = false;
    if (!shouldResume || status.value != GameStatus.paused) return;
    if (_bleEnabled && !(_bleService?.isConnected ?? false)) {
      status.value = GameStatus.locked;
      return;
    }
    status.value = GameStatus.playing;
    resumeEngine();
  }

  /// 连接设备后开始游戏；调试模式可将 enableBle 设为 false。
  void start({required int maxUiIntensity, required bool enableBle}) {
    final wasPaused = status.value == GameStatus.paused;
    _maxUiIntensity = maxUiIntensity.clamp(0, 180);
    _bleEnabled = enableBle;
    if (enableBle && !(_bleService?.isConnected ?? false)) {
      status.value = GameStatus.locked;
      pauseEngine();
      return;
    }
    if (wasPaused && !_resumeAfterOverlay) {
      // 打开设置前本来就是暂停状态，保存设置后仍保持暂停。
      status.value = GameStatus.paused;
      pauseEngine();
    } else {
      status.value = GameStatus.playing;
      resumeEngine();
    }
  }

  void reset() {
    unawaited(_bleScheduler?.stop());
    _physics.reset();
    _elapsedSeconds = 0;
    elapsed.value = Duration.zero;
    status.value = (_bleEnabled && !(_bleService?.isConnected ?? false))
        ? GameStatus.locked
        : GameStatus.playing;
    _tilt.stopTouch();
    resumeEngine();
  }

  /// 切换地图时重建物理对象，保证碰撞网格和起点同步更新。
  void selectLevel(MazeLevel nextLevel) {
    final previousStatus = status.value;
    unawaited(_bleScheduler?.stop());
    _level = nextLevel;
    _physics = BallPhysics(level: nextLevel);
    level.value = nextLevel;
    MazeThemeCatalog.current.value = nextLevel.theme;
    _elapsedSeconds = 0;
    elapsed.value = Duration.zero;
    _tilt.stopTouch();

    // 通关后切换地图要恢复到可玩的状态，不能把 completed 带到新地图。
    if (previousStatus == GameStatus.completed) {
      status.value = (_bleEnabled && !(_bleService?.isConnected ?? false))
          ? GameStatus.locked
          : GameStatus.playing;
      resumeEngine();
    }
  }

  void calibrate() {
    _tilt.calibrate();
  }

  void setScreenOrientation(TiltOrientation orientation) {
    _tilt.setOrientation(orientation);
  }

  void setInputMode(InputMode mode) {
    _tilt.setInputMode(mode);
  }

  void handleTouch(Offset screenPosition) {
    if (inputMode.value != InputMode.touch || _boardRect == Rect.zero) return;
    final center = _boardRect.center;
    final range = _boardRect.shortestSide * 0.34;
    final direction = screenPosition - center;
    _tilt.setTouchInput(
      Offset(
        (direction.dx / range).clamp(-1.0, 1.0).toDouble(),
        (direction.dy / range).clamp(-1.0, 1.0).toDouble(),
      ),
    );
  }

  void endTouch() {
    _tilt.stopTouch();
  }

  @override
  void dispose() {
    _tilt.inputMode.removeListener(_syncInputMode);
    _tilt.sensorAvailable.removeListener(_syncSensorAvailable);
    _bleService?.status.removeListener(_syncBleStatus);
    _bleScheduler?.currentUiIntensity.removeListener(_syncCurrentUiIntensity);
    _tilt.dispose();
    unawaited(_bleScheduler?.dispose());
    status.dispose();
    elapsed.dispose();
    inputMode.dispose();
    sensorAvailable.dispose();
    currentUiIntensity.dispose();
    level.dispose();
    super.dispose();
  }

  void _syncInputMode() {
    inputMode.value = _tilt.inputMode.value;
  }

  void _syncSensorAvailable() {
    sensorAvailable.value = _tilt.sensorAvailable.value;
  }

  void stopBleOutput() {
    unawaited(_bleScheduler?.stop());
    currentUiIntensity.value = 0;
  }

  void _syncCurrentUiIntensity() {
    final scheduler = _bleScheduler;
    if (scheduler != null) {
      currentUiIntensity.value = scheduler.currentUiIntensity.value;
    }
  }

  void _syncBleStatus() {
    if (!_bleEnabled || status.value == GameStatus.completed) return;
    if (!(_bleService?.isConnected ?? false)) {
      _bleEnabled = false;
      status.value = GameStatus.locked;
      unawaited(_bleScheduler?.stop());
      pauseEngine();
    }
  }

  void _onBleError(Object error) {
    _bleEnabled = false;
    status.value = GameStatus.locked;
    unawaited(_bleScheduler?.stop());
    pauseEngine();
  }

  void _drawGoal(Canvas canvas, double left, double top, double tile) {
    final theme = _level.theme;
    final center = Offset(
      left + (_level.goalCell.x + 0.5) * tile,
      top + (_level.goalCell.y + 0.5) * tile,
    );
    final pulse = 0.8 + math.sin(_elapsedSeconds * 3) * 0.08;
    canvas.drawCircle(
      center,
      tile * 0.31 * pulse,
      Paint()..color = theme.secondary.withValues(alpha: 0.2),
    );
    canvas.drawCircle(
      center,
      tile * 0.2,
      Paint()..color = theme.secondary,
    );
    canvas.drawCircle(
      center,
      tile * 0.08,
      Paint()..color = theme.text,
    );
  }

  void _drawBall(Canvas canvas, double left, double top, double tile) {
    final theme = _level.theme;
    final center = Offset(
      left + _physics.position.dx * tile,
      top + _physics.position.dy * tile,
    );
    canvas.drawCircle(
      center + Offset(tile * 0.045, tile * 0.06),
      tile * 0.27,
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );
    final ballPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.9,
        colors: [theme.ballLight, theme.ballDark],
      ).createShader(
        Rect.fromCircle(center: center, radius: tile * 0.27),
      );
    canvas.drawCircle(center, tile * 0.27, ballPaint);
    canvas.drawCircle(
      center - Offset(tile * 0.08, tile * 0.09),
      tile * 0.055,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }
}
