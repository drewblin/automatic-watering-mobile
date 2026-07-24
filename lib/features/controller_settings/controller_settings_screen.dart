import 'package:flutter/material.dart';

import '../watering_hubs/watering_hub_connection_state_label.dart';
import '../watering_hubs/watering_hub_state.dart';
import 'controller_settings.dart';
import 'device_objects.dart';
import 'settings_response_data.dart';

class ControllerSettingsScreen extends StatefulWidget {
  const ControllerSettingsScreen({
    required this.settings,
    required this.deviceObjects,
    required this.connectionState,
    super.key,
  });

  final SettingsResponseData settings;
  final List<DeviceObject> deviceObjects;
  final WateringHubConnectionState connectionState;

  @override
  State<ControllerSettingsScreen> createState() =>
      _ControllerSettingsScreenState();
}

class _ControllerSettingsScreenState extends State<ControllerSettingsScreen> {
  final _startThresholdController = TextEditingController();
  final _stopThresholdController = TextEditingController();
  final _zoneDurationController = TextEditingController();
  ControllerSettings? _draftSource;

  @override
  void initState() {
    super.initState();
    _syncDraftFromSettings();
  }

  @override
  void didUpdateWidget(covariant ControllerSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.settings.settings, oldWidget.settings.settings)) {
      _syncDraftFromSettings();
    }
  }

  @override
  void dispose() {
    _startThresholdController.dispose();
    _stopThresholdController.dispose();
    _zoneDurationController.dispose();
    super.dispose();
  }

  void _syncDraftFromSettings() {
    final settings = widget.settings.settings;
    if (identical(settings, _draftSource)) {
      return;
    }
    _draftSource = settings;
    _startThresholdController.text =
        settings.globalSettings.startWateringBelowHumidityPercent.toString();
    _stopThresholdController.text =
        settings.globalSettings.stopWateringAboveHumidityPercent.toString();
    _zoneDurationController.text =
        settings.globalSettings.zoneWateringDurationSeconds.toString();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування контролера')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSummary(
            settings: widget.settings,
            connectionState: widget.connectionState,
          ),
          const SizedBox(height: 16),
          _GlobalSettingsEditor(
            settings: settings.globalSettings,
            startThresholdController: _startThresholdController,
            stopThresholdController: _stopThresholdController,
            zoneDurationController: _zoneDurationController,
            onReset: _syncDraftFromSettings,
          ),
          const SizedBox(height: 16),
          _DeviceObjectList(deviceObjects: widget.deviceObjects),
        ],
      ),
    );
  }
}

class _SettingsSummary extends StatelessWidget {
  const _SettingsSummary({
    required this.settings,
    required this.connectionState,
  });

  final SettingsResponseData settings;
  final WateringHubConnectionState connectionState;

  @override
  Widget build(BuildContext context) {
    final controllerSettings = settings.settings;
    final valves = controllerSettings.valveSettings.length;
    final soilSensors = controllerSettings.soilSensorSettings.length;
    final magistralWaterCounterCount =
        controllerSettings.magistralWaterCounterSetting == null ? 0 : 1;
    final waterCounters = controllerSettings.leafWaterCounterSettings.length +
        magistralWaterCounterCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Статус HTTPS: ${connectionState.label}'),
        const SizedBox(height: 8),
        Text(
          'Налаштування завантажені: ${_formatSyncedAt(settings.syncedAt)}',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('Valves: $valves'),
            Text('Soil sensors: $soilSensors'),
            Text('Water counters: $waterCounters'),
          ],
        ),
      ],
    );
  }
}

class _GlobalSettingsEditor extends StatelessWidget {
  const _GlobalSettingsEditor({
    required this.settings,
    required this.startThresholdController,
    required this.stopThresholdController,
    required this.zoneDurationController,
    required this.onReset,
  });

  final GlobalSettings settings;
  final TextEditingController startThresholdController;
  final TextEditingController stopThresholdController;
  final TextEditingController zoneDurationController;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GlobalSettings',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: startThresholdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'startWateringBelowHumidityPercent',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: stopThresholdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'stopWateringAboveHumidityPercent',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: zoneDurationController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'zoneWateringDurationSeconds',
          ),
        ),
        const SizedBox(height: 12),
        Text('wateringStartMode: ${settings.wateringStartMode.name}'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.restore),
          label: const Text('Скинути чернетку'),
        ),
      ],
    );
  }
}

class _DeviceObjectList extends StatelessWidget {
  const _DeviceObjectList({required this.deviceObjects});

  final List<DeviceObject> deviceObjects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device objects',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (deviceObjects.isEmpty)
          const Text('Device objects ще не побудовані.')
        else
          ...deviceObjects.map(
            (object) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(object.type.icon),
              title: Text(object.displayName),
              subtitle: Text(object.id),
            ),
          ),
      ],
    );
  }
}

String _formatSyncedAt(DateTime? value) {
  if (value == null) {
    return 'ще не виконувалась';
  }
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

extension on DeviceObjectType {
  IconData get icon {
    return switch (this) {
      DeviceObjectType.valve => Icons.water_drop,
      DeviceObjectType.soilSensor => Icons.grass,
      DeviceObjectType.pressureSensor => Icons.speed,
      DeviceObjectType.waterCounter => Icons.pin,
    };
  }
}
