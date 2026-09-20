import 'package:flutter/material.dart';

import '../game/maze_game.dart';
import '../game/maze_theme.dart';
import '../l10n/app_localizations.dart';
import '../sensors/tilt_controller.dart';

class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.elapsed,
    required this.status,
    required this.inputMode,
    required this.sensorAvailable,
    required this.onPause,
    required this.onReset,
    required this.onCalibrate,
    required this.onInputModeChanged,
    required this.connectedDeviceName,
    required this.onDeviceSettings,
    required this.theme,
    required this.mapName,
    required this.onMapSelection,
    required this.maxUiIntensity,
    required this.currentUiIntensity,
    required this.onLocaleChanged,
  });

  final Duration elapsed;
  final GameStatus status;
  final InputMode inputMode;
  final bool sensorAvailable;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onCalibrate;
  final ValueChanged<InputMode> onInputModeChanged;
  final String? connectedDeviceName;
  final VoidCallback onDeviceSettings;
  final MazeThemeData theme;
  final String mapName;
  final VoidCallback onMapSelection;
  final int maxUiIntensity;
  final int currentUiIntensity;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final displayedIntensity = currentUiIntensity.clamp(0, 180);
    final l10n = AppLocalizations.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 560 || constraints.maxHeight < 540;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 28,
                compact ? 12 : 22,
                compact ? 14 : 28,
                compact ? 12 : 22,
              ),
              child: Column(
                children: [
                  _TopHeader(
                    mapName: mapName,
                    theme: theme,
                    onMapSelection: onMapSelection,
                    onPause: onPause,
                    onReset: onReset,
                    paused: status == GameStatus.paused,
                    onLocaleChanged: onLocaleChanged,
                  ),
                  if (status == GameStatus.locked)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _StatusPill(
                          label: l10n.text('disconnected'),
                          icon: Icons.lock_outline_rounded,
                          theme: theme,
                        ),
                      ),
                    ),
                  const Spacer(),
                  _MetricsRow(
                    minutes: minutes,
                    seconds: seconds,
                    intensity: displayedIntensity,
                    maxIntensity: maxUiIntensity,
                    connectedDeviceName: connectedDeviceName,
                    theme: theme,
                    compact: compact,
                  ),
                  const SizedBox(height: 12),
                  _BottomBar(
                    compact: compact,
                    inputMode: inputMode,
                    sensorAvailable: sensorAvailable,
                    connectedDeviceName: connectedDeviceName,
                    theme: theme,
                    onDeviceSettings: onDeviceSettings,
                    onCalibrate: onCalibrate,
                    onInputModeChanged: onInputModeChanged,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.mapName,
    required this.theme,
    required this.onMapSelection,
    required this.onPause,
    required this.onReset,
    required this.paused,
    required this.onLocaleChanged,
  });

  final String mapName;
  final MazeThemeData theme;
  final VoidCallback onMapSelection;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final bool paused;
  final ValueChanged<Locale> onLocaleChanged;

  Future<void> _showLanguagePicker(BuildContext context) async {
    final selected = await showDialog<Locale>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.text('language')),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: SizedBox(
            width: 320,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: AppLocalizations.supportedLocales.length,
              itemBuilder: (context, index) {
                final locale = AppLocalizations.supportedLocales[index];
                return ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(AppLocalizations.languageNameFor(locale)),
                  onTap: () => Navigator.of(dialogContext).pop(locale),
                );
              },
            ),
          ),
        );
      },
    );
    if (selected != null) onLocaleChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.text('offlineRun'),
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 10,
                  letterSpacing: 2.2,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mapName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.text,
                  fontFamily: 'serif',
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _HudIconButton(
          tooltip: l10n.text('mapSelect'),
          icon: Icons.grid_view_rounded,
          theme: theme,
          onPressed: onMapSelection,
        ),
        const SizedBox(width: 8),
        _HudIconButton(
          tooltip: l10n.text('language'),
          icon: Icons.language_rounded,
          theme: theme,
          onPressed: () => _showLanguagePicker(context),
        ),
        const SizedBox(width: 8),
        _HudIconButton(
          tooltip: l10n.text('restart'),
          icon: Icons.replay_rounded,
          theme: theme,
          onPressed: onReset,
        ),
        const SizedBox(width: 8),
        _HudIconButton(
          tooltip: paused ? l10n.text('resume') : l10n.text('pause'),
          icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          theme: theme,
          onPressed: onPause,
        ),
      ],
    );
  }
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.tooltip,
    required this.icon,
    required this.theme,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final MazeThemeData theme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: theme.text),
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(CircleBorder()),
          side: WidgetStatePropertyAll(
            BorderSide(color: theme.border.withValues(alpha: 0.72)),
          ),
          backgroundColor: WidgetStatePropertyAll(
            theme.background.withValues(alpha: 0.36),
          ),
        ),
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.minutes,
    required this.seconds,
    required this.intensity,
    required this.maxIntensity,
    required this.connectedDeviceName,
    required this.theme,
    required this.compact,
  });

  final String minutes;
  final String seconds;
  final int intensity;
  final int maxIntensity;
  final String? connectedDeviceName;
  final MazeThemeData theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final device = connectedDeviceName == null
        ? l10n.text('notConnected')
        : connectedDeviceName!.replaceAll(RegExp(r'（.*?）'), '');
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: l10n.text('time'),
            value: '$minutes:$seconds',
            detail: l10n.text('currentRun'),
            theme: theme,
            compact: compact,
          ),
        ),
        Expanded(
          child: _Metric(
            label: l10n.text('wallOutput'),
            value: '$intensity',
            detail: '${l10n.text('max')} $maxIntensity',
            theme: theme,
            accent: true,
            compact: compact,
          ),
        ),
        Expanded(
          child: _Metric(
            label: l10n.text('device'),
            value: device,
            detail: connectedDeviceName == null
                ? l10n.text('offline')
                : l10n.text('sync'),
            theme: theme,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
    required this.theme,
    required this.compact,
    this.accent = false,
  });

  final String label;
  final String value;
  final String detail;
  final MazeThemeData theme;
  final bool compact;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.muted,
            fontSize: 10,
            letterSpacing: 1.8,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent ? theme.primary : theme.text,
            fontSize: compact ? 18 : 24,
            fontWeight: FontWeight.w500,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          style: TextStyle(
            color: theme.muted,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.compact,
    required this.inputMode,
    required this.sensorAvailable,
    required this.connectedDeviceName,
    required this.theme,
    required this.onDeviceSettings,
    required this.onCalibrate,
    required this.onInputModeChanged,
  });

  final bool compact;
  final InputMode inputMode;
  final bool sensorAvailable;
  final String? connectedDeviceName;
  final MazeThemeData theme;
  final VoidCallback onDeviceSettings;
  final VoidCallback onCalibrate;
  final ValueChanged<InputMode> onInputModeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deviceButton = OutlinedButton.icon(
      onPressed: onDeviceSettings,
      icon: Icon(Icons.bluetooth_rounded, size: 16, color: theme.primary),
      label: Text(
        connectedDeviceName ?? l10n.text('notConnectedDevice'),
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: theme.text,
        side: BorderSide(color: theme.border.withValues(alpha: 0.72)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    final modeSelector = _ModeSelector(
      mode: inputMode,
      sensorAvailable: sensorAvailable,
      onChanged: onInputModeChanged,
      theme: theme,
    );
    final calibrateButton = Tooltip(
      message: l10n.text('calibrate'),
      child: IconButton(
        onPressed: onCalibrate,
        icon: Icon(Icons.center_focus_strong_rounded, color: theme.text),
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(CircleBorder()),
          side: WidgetStatePropertyAll(
            BorderSide(color: theme.border.withValues(alpha: 0.72)),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: theme.border.withValues(alpha: 0.55))),
      ),
      child: compact
          ? Column(
              children: [
                SizedBox(width: double.infinity, child: deviceButton),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: modeSelector),
                    const SizedBox(width: 8),
                    calibrateButton,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: deviceButton),
                const SizedBox(width: 10),
                SizedBox(width: 220, child: modeSelector),
                const SizedBox(width: 8),
                calibrateButton,
              ],
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final MazeThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.board.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: theme.text)),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.sensorAvailable,
    required this.onChanged,
    required this.theme,
  });

  final InputMode mode;
  final bool sensorAvailable;
  final ValueChanged<InputMode> onChanged;
  final MazeThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<InputMode>(
      segments: [
        ButtonSegment(
          value: InputMode.tilt,
          icon: const Icon(Icons.screen_rotation_alt_rounded),
          label: Text(AppLocalizations.of(context).text('tilt')),
          enabled: sensorAvailable,
        ),
        ButtonSegment(
          value: InputMode.touch,
          icon: Icon(Icons.touch_app_rounded),
          label: Text(AppLocalizations.of(context).text('touch')),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (values) => onChanged(values.first),
      style: ButtonStyle(
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        foregroundColor: WidgetStatePropertyAll(theme.text),
        side: WidgetStatePropertyAll(
          BorderSide(color: theme.border.withValues(alpha: 0.72)),
        ),
      ),
      emptySelectionAllowed: false,
    );
  }
}
