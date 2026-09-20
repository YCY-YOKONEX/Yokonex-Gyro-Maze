import 'package:flutter/material.dart';

import '../bluetooth/ble_connection_service.dart';
import '../bluetooth/ble_device_model.dart';
import '../bluetooth/ble_permission_service.dart';
import '../bluetooth/ble_protocol.dart';
import '../l10n/app_localizations.dart';

class DeviceStartResult {
  const DeviceStartResult({required this.useBle, required this.maxUiIntensity});

  final bool useBle;
  final int maxUiIntensity;
}

/// 开始游戏前连接 YYC-DJ，并设置 UI 强度上限（0-180）。
class DeviceStartDialog extends StatefulWidget {
  const DeviceStartDialog({
    super.key,
    required this.service,
    this.initial = true,
    this.initialMaxIntensity = 0,
  });

  final BleConnectionService service;
  final bool initial;
  final int initialMaxIntensity;

  @override
  State<DeviceStartDialog> createState() => _DeviceStartDialogState();
}

class _DeviceStartDialogState extends State<DeviceStartDialog> {
  List<BleDeviceInfo> _devices = const [];
  int _maxIntensity = 0;
  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _maxIntensity = widget.initialMaxIntensity.clamp(0, IntensityMapper.uiMax);
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final devices = await widget.service.scan();
      if (!mounted) return;
      setState(() => _devices = devices);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(BleDeviceInfo info) async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await widget.service.connect(info);
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '连接失败：$error');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final connected = widget.service.connectedDevice.value;
    return AlertDialog(
      title: Text(widget.initial
          ? l10n.text('connectDevice')
          : l10n.text('deviceSettings')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connected == null
                    ? l10n.text('chooseDevice')
                    : l10n.text(
                        'currentDevice', {'value': connected.displayName}),
              ),
              const SizedBox(height: 12),
              if (_scanning)
                const LinearProgressIndicator()
              else if (_devices.isEmpty && connected == null)
                Text(l10n.text('noDevices'))
              else
                ..._devices.map(
                  (device) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      device.generation == BleDeviceGeneration.v2
                          ? Icons.looks_two_rounded
                          : Icons.looks_one_rounded,
                    ),
                    title: Text(device.displayName),
                    subtitle: Text(
                      '${device.generationLabel}'
                      '${device.rssi == null ? '' : '  RSSI ${device.rssi}'}',
                    ),
                    trailing: FilledButton(
                      onPressed: _connecting ? null : () => _connect(device),
                      child: Text(l10n.text('connect')),
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                if (_error!.contains('永久拒绝'))
                  TextButton.icon(
                    onPressed: BlePermissionService.openSettings,
                    icon: const Icon(Icons.settings_rounded),
                    label: Text(l10n.text('openSettings')),
                  ),
              ],
              const SizedBox(height: 16),
              Text(l10n.text('maxIntensity', {
                'value': '$_maxIntensity',
                'max': '${IntensityMapper.uiMax}',
              })),
              Slider(
                min: IntensityMapper.uiMin.toDouble(),
                max: IntensityMapper.uiMax.toDouble(),
                divisions: IntensityMapper.uiMax,
                value: _maxIntensity.toDouble(),
                label: '$_maxIntensity',
                onChanged: (value) =>
                    setState(() => _maxIntensity = value.round()),
              ),
              if (connected == null)
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    DeviceStartResult(
                      useBle: false,
                      maxUiIntensity: _maxIntensity,
                    ),
                  ),
                  icon: const Icon(Icons.touch_app_rounded),
                  label: Text(l10n.text('touchDebug')),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _scanning ? null : _scan,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n.text('rescan')),
        ),
        FilledButton.icon(
          onPressed: connected == null || _connecting
              ? null
              : () => Navigator.of(context).pop(
                    DeviceStartResult(
                      useBle: true,
                      maxUiIntensity: _maxIntensity,
                    ),
                  ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(widget.initial
              ? l10n.text('startGame')
              : l10n.text('saveContinue')),
        ),
      ],
    );
  }
}
