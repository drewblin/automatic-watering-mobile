import 'package:flutter/material.dart';

import '../controller_settings/controller_settings.dart';
import '../controller_settings/device_objects.dart';
import '../sensors/sensor_metric.dart';
import 'home_dashboard_controller.dart';
import 'home_metric_widgets.dart';
import 'open_valve_dialog.dart';

class ValveCard extends StatelessWidget {
  const ValveCard({
    required this.valve,
    required this.settings,
    required this.humidity,
    required this.temperature,
    required this.commandState,
    required this.onOpen,
    super.key,
  });

  final ValveObject valve;
  final ControllerSettings settings;
  final SensorMetric? humidity;
  final SensorMetric? temperature;
  final ManualValveCommandState commandState;
  final Future<void> Function(int seconds) onOpen;

  @override
  Widget build(BuildContext context) {
    final sending = commandState.status == ManualValveCommandStatus.sending &&
        commandState.valvePin == valve.setting.pin;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valve.setting.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            MetricRow(
              displays: [
                MetricDisplay(
                  label: 'Вологість',
                  metric: humidity,
                  suffix: '%',
                ),
                MetricDisplay(
                  label: 'Температура',
                  metric: temperature,
                  suffix: '°C',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: sending
                    ? null
                    : () async {
                        final seconds = await showOpenValveDialog(
                          context: context,
                          valveName: valve.setting.name,
                          defaultSeconds: _defaultValveSeconds(settings),
                          maxSeconds: settings
                              .globalSettings.maximumManualValveOpenTimeSeconds,
                        );
                        if (seconds != null) {
                          await onOpen(seconds);
                        }
                      },
                icon: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.water_drop),
                label: const Text('Відкрити клапан'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SensorCard extends StatelessWidget {
  const SensorCard({
    required this.title,
    required this.metrics,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<MetricDisplay> metrics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle case final subtitle?) ...[
              const SizedBox(height: 2),
              Text(subtitle),
            ],
            const SizedBox(height: 12),
            MetricRow(displays: metrics),
          ],
        ),
      ),
    );
  }
}

int _defaultValveSeconds(ControllerSettings settings) {
  final defaultSeconds = settings.globalSettings.zoneWateringDurationSeconds;
  final maxSeconds = settings.globalSettings.maximumManualValveOpenTimeSeconds;
  return defaultSeconds > maxSeconds ? maxSeconds : defaultSeconds;
}
