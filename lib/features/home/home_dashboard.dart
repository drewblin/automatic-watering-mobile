import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../controller_settings/controller_settings.dart';
import '../controller_settings/device_objects.dart';
import 'home_dashboard_controller.dart';
import 'home_dashboard_status.dart';
import 'home_device_cards.dart';
import 'home_formatters.dart';
import 'home_metric_widgets.dart';
import 'home_section.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({
    required this.state,
    required this.controller,
    super.key,
  });

  final AppState state;
  final HomeDashboardController controller;

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  var _initialRefreshStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startInitialRefresh();
  }

  @override
  void didUpdateWidget(HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.readyWateringHub.id !=
        oldWidget.state.readyWateringHub.id) {
      _initialRefreshStarted = false;
      _startInitialRefresh();
    }
  }

  void _startInitialRefresh() {
    if (_initialRefreshStarted) {
      return;
    }
    _initialRefreshStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _DashboardBody(
        state: widget.state,
        controller: widget.controller,
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.state,
    required this.controller,
  });

  final AppState state;
  final HomeDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final hub = state.readyWateringHub;
    final settings = state.readySettings;
    final controllerSettings = settings.settings;
    final valves = state.deviceObjects.whereType<ValveObject>().toList();
    final soilSensors =
        state.deviceObjects.whereType<SoilSensorObject>().toList();
    final pressureSensors =
        state.deviceObjects.whereType<PressureSensorObject>().toList();
    final waterCounters =
        state.deviceObjects.whereType<WaterCounterObject>().toList();
    final metrics = MetricIndex(controller.metrics);

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DashboardStatusCard(
              hubName: hub.displayName,
              settingsSyncedAt: settings.syncedAt,
              controllerCurrentTime: controllerTimeText(settings),
              lastMetricsSyncedAt: controller.lastMetricsSyncedAt,
              refreshStatus: controller.refreshStatus,
              errorMessage: controller.refreshErrorMessage,
              onRefresh: controller.isRefreshing ? null : controller.refresh,
            ),
            const SizedBox(height: 16),
            HomeSection(
              title: 'Клапани',
              emptyText: 'Клапани не налаштовані.',
              children: [
                for (final valve in valves)
                  ValveCard(
                    valve: valve,
                    settings: controllerSettings,
                    humidity: metrics.soilHumidity(
                      valve.setting.soilSensorSlaveAddress,
                    ),
                    temperature: metrics.soilTemperature(
                      valve.setting.soilSensorSlaveAddress,
                    ),
                    commandState: controller.manualValveState,
                    onOpen: (seconds) => _openValve(
                      context,
                      valve,
                      seconds,
                      controllerSettings,
                    ),
                  ),
              ],
            ),
            HomeSection(
              title: 'Датчики вологості грунту',
              emptyText: 'Датчики вологості не налаштовані.',
              children: [
                for (final sensor in soilSensors)
                  SensorCard(
                    title: sensor.setting.name,
                    metrics: [
                      MetricDisplay(
                        label: 'Вологість',
                        metric: metrics.soilHumidity(
                          sensor.setting.slaveAddress,
                        ),
                        suffix: '%',
                      ),
                      MetricDisplay(
                        label: 'Температура',
                        metric: metrics.soilTemperature(
                          sensor.setting.slaveAddress,
                        ),
                        suffix: '°C',
                      ),
                    ],
                  ),
              ],
            ),
            HomeSection(
              title: 'Датчик тиску',
              emptyText: 'Датчик тиску не налаштований.',
              children: [
                for (final sensor in pressureSensors)
                  SensorCard(
                    title: sensor.setting.name,
                    metrics: [
                      MetricDisplay(
                        label: 'Тиск',
                        metric: metrics.pressure(sensor.setting.slaveAddress),
                        suffix: 'bar',
                      ),
                    ],
                  ),
              ],
            ),
            HomeSection(
              title: 'Лічильники води',
              emptyText: 'Лічильники води не налаштовані.',
              children: [
                for (final counter in waterCounters)
                  SensorCard(
                    title: counter.setting.name,
                    subtitle: counter.kind == WaterCounterObjectKind.magistral
                        ? 'Магістральний лічильник'
                        : 'Лічильник гілки',
                    metrics: [
                      MetricDisplay(
                        label: 'Загалом від старту',
                        metric: metrics.waterCounter(counter.setting.pin),
                        suffix: 'л',
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openValve(
    BuildContext context,
    ValveObject valve,
    int seconds,
    ControllerSettings controllerSettings,
  ) async {
    final success = await controller.openValveForTime(
      valve: valve.setting,
      seconds: seconds,
      settings: controllerSettings,
    );
    if (!context.mounted) {
      return;
    }
    final message = controller.manualValveState.message;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    if (success) {
      controller.resetManualValveState();
    }
  }
}
