import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flame/game.dart';

import 'bluetooth/ble_connection_service.dart';
import 'bluetooth/ble_device_model.dart';
import 'game/maze_game.dart';
import 'game/maze_level.dart';
import 'game/maze_theme.dart';
import 'l10n/app_localizations.dart';
import 'sensors/tilt_controller.dart';
import 'ui/device_start_dialog.dart';
import 'ui/game_hud.dart';
import 'ui/map_selection_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GyroMazeApp());
}

class GyroMazeApp extends StatefulWidget {
  const GyroMazeApp({super.key});

  @override
  State<GyroMazeApp> createState() => _GyroMazeAppState();
}

class _GyroMazeAppState extends State<GyroMazeApp> {
  Locale? _locale;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MazeThemeData>(
      valueListenable: MazeThemeCatalog.current,
      builder: (context, style, _) {
        return MaterialApp(
          title: 'Lunar Maze Challenge',
          debugShowCheckedModeBanner: false,
          locale: _locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supported) {
            if (locale == null) return supported.first;
            return supported.firstWhere(
              (item) => item.languageCode == locale.languageCode,
              orElse: () => supported.first,
            );
          },
          theme: buildMazeMaterialTheme(style),
          home: MazePage(onLocaleChanged: (locale) {
            setState(() => _locale = locale);
          }),
        );
      },
    );
  }
}

class MazePage extends StatefulWidget {
  const MazePage({super.key, required this.onLocaleChanged});

  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<MazePage> createState() => _MazePageState();
}

class _MazePageState extends State<MazePage> with WidgetsBindingObserver {
  late final BleConnectionService _bleService;
  late final MazeGame _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bleService = BleConnectionService();
    _game = MazeGame(bleService: _bleService);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStartDialog());
  }

  Future<void> _showStartDialog() async {
    if (!mounted) return;
    final result = await showDialog<DeviceStartResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeviceStartDialog(service: _bleService),
    );
    if (!mounted) return;
    _game.start(
      maxUiIntensity: result?.maxUiIntensity ?? 0,
      enableBle: result?.useBle ?? false,
    );
    _game.resumeAfterDeviceSettings();
    if (result?.useBle != true) _game.setInputMode(InputMode.touch);
  }

  Future<void> _showDeviceSettings() async {
    if (!mounted) return;
    _game.pauseForDeviceSettings();
    final result = await showDialog<DeviceStartResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DeviceStartDialog(
        service: _bleService,
        initial: false,
        initialMaxIntensity: _game.maxUiIntensity,
      ),
    );
    if (!mounted) return;
    if (result == null) {
      _game.resumeAfterDeviceSettings();
      return;
    }
    _game.start(
      maxUiIntensity: result.maxUiIntensity,
      enableBle: result.useBle,
    );
    _game.resumeAfterDeviceSettings();
    if (!result.useBle) _game.setInputMode(InputMode.touch);
  }

  Future<void> _showMapSelection() async {
    if (!mounted) return;
    _game.pauseForDeviceSettings();
    final selected = await showDialog<MazeLevel>(
      context: context,
      barrierDismissible: true,
      builder: (_) => MapSelectionDialog(currentLevel: _game.level.value),
    );
    if (!mounted) return;
    if (selected == null) {
      _game.resumeAfterDeviceSettings();
      return;
    }
    _game.selectLevel(selected);
    _game.resumeAfterDeviceSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.stopBleOutput();
    _game.dispose();
    unawaited(_bleService.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _game.pauseForAppLifecycle();
    } else if (state == AppLifecycleState.resumed) {
      _game.resumeAfterAppLifecycle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    _game.setScreenOrientation(
      isLandscape ? TiltOrientation.landscapeLeft : TiltOrientation.portrait,
    );
    return ValueListenableBuilder<MazeLevel>(
      valueListenable: _game.level,
      builder: (context, currentLevel, _) {
        return AnimatedTheme(
          data: buildMazeMaterialTheme(currentLevel.theme),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Scaffold(
            body: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      _game.handleTouch(details.localPosition);
                    },
                    onPanEnd: (_) => _game.endTouch(),
                    onPanCancel: _game.endTouch,
                    onTapUp: (_) => _game.endTouch(),
                    onTapCancel: _game.endTouch,
                    onTapDown: (details) {
                      if (_game.inputMode.value == InputMode.touch) {
                        _game.handleTouch(details.localPosition);
                      }
                    },
                    child: GameWidget(game: _game),
                  ),
                  ValueListenableBuilder<Duration>(
                    valueListenable: _game.elapsed,
                    builder: (context, elapsed, _) {
                      return ValueListenableBuilder<GameStatus>(
                        valueListenable: _game.status,
                        builder: (context, status, __) {
                          return ValueListenableBuilder<InputMode>(
                            valueListenable: _game.inputMode,
                            builder: (context, inputMode, ___) {
                              return ValueListenableBuilder<bool>(
                                valueListenable: _game.sensorAvailable,
                                builder: (context, sensorAvailable, ____) {
                                  return ValueListenableBuilder<BleDeviceInfo?>(
                                    valueListenable:
                                        _bleService.connectedDevice,
                                    builder: (context, connectedDevice, _____) {
                                      return ValueListenableBuilder<int>(
                                        valueListenable:
                                            _game.currentUiIntensity,
                                        builder:
                                            (context, currentIntensity, _____) {
                                          return ValueListenableBuilder<
                                              MazeLevel>(
                                            valueListenable: _game.level,
                                            builder: (context, level, ______) {
                                              return GameHud(
                                                elapsed: elapsed,
                                                status: status,
                                                inputMode: inputMode,
                                                sensorAvailable:
                                                    sensorAvailable,
                                                theme: level.theme,
                                                mapName:
                                                    AppLocalizations.of(context)
                                                        .mapName(level.id,
                                                            level.name),
                                                connectedDeviceName:
                                                    connectedDevice
                                                        ?.displayName,
                                                maxUiIntensity:
                                                    _game.maxUiIntensity,
                                                currentUiIntensity:
                                                    currentIntensity,
                                                onDeviceSettings:
                                                    _showDeviceSettings,
                                                onMapSelection:
                                                    _showMapSelection,
                                                onPause: _game.togglePause,
                                                onReset: _game.reset,
                                                onCalibrate: _game.calibrate,
                                                onInputModeChanged:
                                                    _game.setInputMode,
                                                onLocaleChanged:
                                                    widget.onLocaleChanged,
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<GameStatus>(
                    valueListenable: _game.status,
                    builder: (context, status, _) {
                      if (status != GameStatus.completed) {
                        return const SizedBox.shrink();
                      }
                      return _CompletionPanel(
                        elapsed: _game.elapsed.value,
                        theme: _game.level.value.theme,
                        onReset: _game.reset,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompletionPanel extends StatelessWidget {
  const _CompletionPanel({
    required this.elapsed,
    required this.theme,
    required this.onReset,
  });

  final Duration elapsed;
  final MazeThemeData theme;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final seconds = elapsed.inMilliseconds / 1000;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: theme.background.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.secondary.withValues(alpha: 0.82),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, size: 42, color: theme.secondary),
            const SizedBox(height: 12),
            Text(
              l10n.text('complete'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.text,
                    fontFamily: 'serif',
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.text('duration', {'value': seconds.toStringAsFixed(1)}),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: theme.muted,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.replay_rounded),
              label: Text(l10n.text('again')),
            ),
          ],
        ),
      ),
    );
  }
}
