import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_header.dart';
import '../service_console/service_console_dependencies.dart';
import 'controller_settings.dart';
import 'controller_settings_form_draft.dart';
import 'controller_settings_save_controller.dart';
import 'device_objects.dart';
import 'settings_response_data.dart';

class ControllerSettingsScreen extends StatefulWidget {
  const ControllerSettingsScreen({
    required this.settings,
    required this.deviceObjects,
    required this.saveController,
    required this.serviceConsoleDependencies,
    super.key,
  });

  final SettingsResponseData settings;
  final List<DeviceObject> deviceObjects;
  final ControllerSettingsSaveController saveController;
  final ServiceConsoleDependencies serviceConsoleDependencies;

  @override
  State<ControllerSettingsScreen> createState() =>
      _ControllerSettingsScreenState();
}

class _ControllerSettingsScreenState extends State<ControllerSettingsScreen> {
  late ControllerSettingsFormDraft _draft;
  late ControllerSettingsValidationResult _validation;
  ControllerSettingsSaveFlowState _flow =
      const ControllerSettingsSaveFlowState.ready();
  StreamSubscription<ControllerSettingsSaveFlowState>? _flowSubscription;
  final _fieldKeys = <String, GlobalKey>{};

  bool get _busy => _flow.isBusy;

  bool get _dirty => _draft.differsFrom(widget.settings.settings);

  bool get _canSave => !_busy;

  @override
  void initState() {
    super.initState();
    _resetDraft();
    _flowSubscription = widget.saveController.states.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _flow = state;
      });
      if (state.status == ControllerSettingsSaveFlowStatus.reconnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message!)),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _flowSubscription?.cancel();
    super.dispose();
  }

  void _resetDraft() {
    _draft = ControllerSettingsFormDraft.fromSettings(widget.settings.settings);
    _validation = _draft.validate();
  }

  Future<void> _save() async {
    setState(() {
      _validation = _draft.validate();
    });
    if (!_validation.isValid) {
      _scrollToFirstError();
      return;
    }
    if (_busy) {
      return;
    }
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    await widget.saveController.save(_draft.buildSettings());
  }

  void _scrollToFirstError() {
    for (final key in _validation.errors.keys) {
      final context = _fieldKeys[key]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.12,
        );
        return;
      }
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty && !_busy) {
      return true;
    }
    final action = await showDialog<_LeaveAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_busy ? 'Перервати процес?' : 'Є незбережені зміни'),
        content: Text(
          _busy
              ? 'Збереження або відновлення зʼєднання ще триває.'
              : 'Ви можете залишитися на сторінці або вийти без збереження.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveAction.stay),
            child: const Text('Залишитися'),
          ),
          if (!_busy && _validation.isValid)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_LeaveAction.save),
              child: const Text('Зберегти'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveAction.leave),
            child: const Text('Вийти без збереження'),
          ),
        ],
      ),
    );
    if (action == _LeaveAction.save) {
      await _save();
      return false;
    }
    return action == _LeaveAction.leave;
  }

  void _changed(VoidCallback update) {
    setState(() {
      update();
      _validation = _draft.validate();
      _flow = ControllerSettingsSaveFlowState(
        status: _validation.isValid
            ? ControllerSettingsSaveFlowStatus.dirty
            : ControllerSettingsSaveFlowStatus.invalid,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        if (await _confirmLeave() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppHeader(
          title: 'Налаштування контролера',
          serviceConsoleDependencies: widget.serviceConsoleDependencies,
          actions: [
            TextButton(
              onPressed: _canSave ? _save : null,
              child: const Text('Зберегти'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(
              message: _flow.message ??
                  'Налаштування завантажені: ${_formatSyncedAt(widget.settings.syncedAt)}',
              isError:
                  _flow.status == ControllerSettingsSaveFlowStatus.saveFailed ||
                      _flow.status ==
                          ControllerSettingsSaveFlowStatus.reconnectFailed,
              onRetry: _flow.status ==
                      ControllerSettingsSaveFlowStatus.reconnectFailed
                  ? _save
                  : null,
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Загальні налаштування',
              children: [
                _NumberField(
                  scrollKey:
                      _keyFor('global.maximumManualValveOpenTimeSeconds'),
                  enabled: !_busy,
                  label: 'Максимальний час ручного відкриття клапана, с',
                  value:
                      _draft.globalSettings.maximumManualValveOpenTimeSeconds,
                  error:
                      _validation['global.maximumManualValveOpenTimeSeconds'],
                  onChanged: (value) => _changed(() => _draft.globalSettings
                      .maximumManualValveOpenTimeSeconds = value),
                ),
                _NumberField(
                  scrollKey:
                      _keyFor('global.startWateringBelowHumidityPercent'),
                  enabled: !_busy,
                  label: 'Починати полив нижче вологості, %',
                  value:
                      _draft.globalSettings.startWateringBelowHumidityPercent,
                  error:
                      _validation['global.startWateringBelowHumidityPercent'],
                  onChanged: (value) => _changed(() => _draft.globalSettings
                      .startWateringBelowHumidityPercent = value),
                ),
                _NumberField(
                  scrollKey: _keyFor('global.stopWateringAboveHumidityPercent'),
                  enabled: !_busy,
                  label: 'Зупиняти полив вище вологості, %',
                  value: _draft.globalSettings.stopWateringAboveHumidityPercent,
                  error: _validation['global.stopWateringAboveHumidityPercent'],
                  onChanged: (value) => _changed(() => _draft
                      .globalSettings.stopWateringAboveHumidityPercent = value),
                ),
                SegmentedButton<WateringStartMode>(
                  segments: const [
                    ButtonSegment(
                      value: WateringStartMode.immediately,
                      label: Text('Одразу'),
                    ),
                    ButtonSegment(
                      value: WateringStartMode.withinWateringWindow,
                      label: Text('У вікні поливу'),
                    ),
                  ],
                  selected: {_draft.globalSettings.wateringStartMode},
                  onSelectionChanged: _busy
                      ? null
                      : (value) => _changed(() => _draft
                          .globalSettings.wateringStartMode = value.single),
                ),
                if (_draft.globalSettings.wateringStartMode ==
                    WateringStartMode.withinWateringWindow) ...[
                  _TimeFields(
                    scrollKey: _keyFor('global.wateringWindowStartTime'),
                    enabled: !_busy,
                    title: 'Початок вікна поливу',
                    hour: _draft.globalSettings.wateringWindowStartHour,
                    minute: _draft.globalSettings.wateringWindowStartMinute,
                    error: _validation['global.wateringWindowStartTime'],
                    onHourChanged: (value) => _changed(() =>
                        _draft.globalSettings.wateringWindowStartHour = value),
                    onMinuteChanged: (value) => _changed(() => _draft
                        .globalSettings.wateringWindowStartMinute = value),
                  ),
                  _TimeFields(
                    scrollKey: _keyFor('global.wateringWindowEndTime'),
                    enabled: !_busy,
                    title: 'Кінець вікна поливу',
                    hour: _draft.globalSettings.wateringWindowEndHour,
                    minute: _draft.globalSettings.wateringWindowEndMinute,
                    error: _validation['global.wateringWindowEndTime'],
                    onHourChanged: (value) => _changed(() =>
                        _draft.globalSettings.wateringWindowEndHour = value),
                    onMinuteChanged: (value) => _changed(() =>
                        _draft.globalSettings.wateringWindowEndMinute = value),
                  ),
                ],
                _NumberField(
                  scrollKey: _keyFor('global.zoneWateringDurationSeconds'),
                  enabled: !_busy,
                  label: 'Тривалість поливу однієї зони, с',
                  value: _draft.globalSettings.zoneWateringDurationSeconds,
                  error: _validation['global.zoneWateringDurationSeconds'],
                  onChanged: (value) => _changed(() => _draft
                      .globalSettings.zoneWateringDurationSeconds = value),
                ),
                _NumberField(
                  scrollKey: _keyFor('global.zoneWateringRetryDelaySeconds'),
                  enabled: !_busy,
                  label: 'Затримка перед повторним поливом зони, с',
                  value: _draft.globalSettings.zoneWateringRetryDelaySeconds,
                  error: _validation['global.zoneWateringRetryDelaySeconds'],
                  onChanged: (value) => _changed(() => _draft
                      .globalSettings.zoneWateringRetryDelaySeconds = value),
                ),
              ],
            ),
            _Section(
              title: 'Віддалені логи',
              children: [
                _TextField(
                  scrollKey: _keyFor('remoteLog.url'),
                  enabled: !_busy,
                  label: 'URL сервера для логів і метрик',
                  value: _draft.remoteLogSettings.url,
                  error: _validation['remoteLog.url'],
                  onChanged: (value) =>
                      _changed(() => _draft.remoteLogSettings.url = value),
                ),
                _TextField(
                  scrollKey: _keyFor('remoteLog.token'),
                  enabled: !_busy,
                  label: 'Token для відправки логів і метрик',
                  value: _draft.remoteLogSettings.token,
                  error: _validation['remoteLog.token'],
                  onChanged: (value) =>
                      _changed(() => _draft.remoteLogSettings.token = value),
                ),
              ],
            ),
            _Section(
              scrollKey: _keyFor('soilSensors'),
              title: 'Датчики вологості грунту',
              error: _validation['soilSensors'],
              actionLabel: 'Додати датчик',
              onAction: _busy
                  ? null
                  : () => _changed(() => _draft.soilSensors.add(
                        SoilSensorSettingDraft(
                          slaveAddress: '',
                          name: '',
                        ),
                      )),
              children: [
                _NumberField(
                  scrollKey:
                      _keyFor('global.idleSoilSensorReadIntervalSeconds'),
                  enabled: !_busy,
                  label: 'Інтервал зчитування у режимі очікування, с',
                  value:
                      _draft.globalSettings.idleSoilSensorReadIntervalSeconds,
                  error:
                      _validation['global.idleSoilSensorReadIntervalSeconds'],
                  onChanged: (value) => _changed(() => _draft.globalSettings
                      .idleSoilSensorReadIntervalSeconds = value),
                ),
                _NumberField(
                  scrollKey:
                      _keyFor('global.wateringSoilSensorReadIntervalSeconds'),
                  enabled: !_busy,
                  label: 'Інтервал зчитування під час поливу, с',
                  value: _draft
                      .globalSettings.wateringSoilSensorReadIntervalSeconds,
                  error: _validation[
                      'global.wateringSoilSensorReadIntervalSeconds'],
                  onChanged: (value) => _changed(() => _draft.globalSettings
                      .wateringSoilSensorReadIntervalSeconds = value),
                ),
                for (var i = 0; i < _draft.soilSensors.length; i += 1)
                  _SoilSensorEditor(
                    enabled: !_busy,
                    index: i,
                    sensor: _draft.soilSensors[i],
                    validation: _validation,
                    onChanged: _changed,
                    onRemove: () => _confirmRemoveSoilSensor(i),
                    keyFor: _keyFor,
                  ),
              ],
            ),
            _PressureSensorEditor(
              enabled: !_busy,
              draft: _draft,
              validation: _validation,
              onChanged: _changed,
              keyFor: _keyFor,
            ),
            _WaterCountersEditor(
              enabled: !_busy,
              draft: _draft,
              validation: _validation,
              onChanged: _changed,
              keyFor: _keyFor,
            ),
            _ValvesEditor(
              enabled: !_busy,
              draft: _draft,
              validation: _validation,
              onChanged: _changed,
              keyFor: _keyFor,
            ),
          ],
        ),
      ),
    );
  }

  GlobalKey _keyFor(String key) {
    return _fieldKeys.putIfAbsent(key, GlobalKey.new);
  }

  Future<void> _confirmRemoveSoilSensor(int index) async {
    final sensor = _draft.soilSensors[index];
    final address = sensor.parsedSlaveAddress;
    final hasBindings = _draft.valves.any(
      (valve) => valve.soilSensorSlaveAddress == address,
    );
    if (hasBindings &&
        !await _confirmDestructive(
          'Видалити датчик вологості?',
          'Клапани, привʼязані до цього датчика, стануть невалідними.',
        )) {
      return;
    }
    _changed(() => _draft.soilSensors.removeAt(index));
  }

  Future<bool> _confirmDestructive(String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

enum _LeaveAction { stay, save, leave }

class _PressureSensorEditor extends StatelessWidget {
  const _PressureSensorEditor({
    required this.enabled,
    required this.draft,
    required this.validation,
    required this.onChanged,
    required this.keyFor,
  });

  final bool enabled;
  final ControllerSettingsFormDraft draft;
  final ControllerSettingsValidationResult validation;
  final void Function(VoidCallback update) onChanged;
  final GlobalKey Function(String key) keyFor;

  @override
  Widget build(BuildContext context) {
    final sensor = draft.pressureSensor;
    return _Section(
      title: 'Датчик тиску',
      actionLabel: sensor == null ? 'Додати датчик' : 'Видалити датчик',
      actionIcon: sensor == null ? Icons.add : Icons.remove_circle_outline,
      onAction: enabled
          ? () => onChanged(() {
                draft.pressureSensor = sensor == null
                    ? PressureSensorSettingDraft(
                        slaveAddress: '',
                        name: '',
                      )
                    : null;
              })
          : null,
      children: [
        _NumberField(
          scrollKey: keyFor('global.idlePressureSensorReadIntervalSeconds'),
          enabled: enabled,
          label: 'Інтервал зчитування у режимі очікування, с',
          value: draft.globalSettings.idlePressureSensorReadIntervalSeconds,
          error: validation['global.idlePressureSensorReadIntervalSeconds'],
          onChanged: (value) => onChanged(() => draft
              .globalSettings.idlePressureSensorReadIntervalSeconds = value),
        ),
        _NumberField(
          scrollKey: keyFor('global.wateringPressureSensorReadIntervalSeconds'),
          enabled: enabled,
          label: 'Інтервал зчитування під час поливу, с',
          value: draft.globalSettings.wateringPressureSensorReadIntervalSeconds,
          error: validation['global.wateringPressureSensorReadIntervalSeconds'],
          onChanged: (value) => onChanged(() => draft.globalSettings
              .wateringPressureSensorReadIntervalSeconds = value),
        ),
        if (sensor == null)
          const Text('Датчик тиску вимкнений.')
        else
          _FieldColumn(children: [
            _NumberField(
              scrollKey: keyFor('pressureSensor.slaveAddress'),
              enabled: enabled,
              label: 'Modbus address',
              value: sensor.slaveAddress,
              error: validation['pressureSensor.slaveAddress'],
              onChanged: (value) =>
                  onChanged(() => sensor.slaveAddress = value),
            ),
            _TextField(
              scrollKey: keyFor('pressureSensor.name'),
              enabled: enabled,
              label: 'Назва датчика',
              value: sensor.name,
              error: validation['pressureSensor.name'],
              onChanged: (value) => onChanged(() => sensor.name = value),
            ),
          ]),
      ],
    );
  }
}

class _WaterCountersEditor extends StatelessWidget {
  const _WaterCountersEditor({
    required this.enabled,
    required this.draft,
    required this.validation,
    required this.onChanged,
    required this.keyFor,
  });

  final bool enabled;
  final ControllerSettingsFormDraft draft;
  final ControllerSettingsValidationResult validation;
  final void Function(VoidCallback update) onChanged;
  final GlobalKey Function(String key) keyFor;

  @override
  Widget build(BuildContext context) {
    final magistral = draft.magistralWaterCounter;
    return Column(
      children: [
        _Section(
          title: 'Магістральний лічильник води',
          actionLabel:
              magistral == null ? 'Додати лічильник' : 'Видалити лічильник',
          actionIcon:
              magistral == null ? Icons.add : Icons.remove_circle_outline,
          onAction: enabled
              ? () => onChanged(() {
                    draft.magistralWaterCounter = magistral == null
                        ? WaterCounterSettingDraft(
                            pin: '',
                            name: '',
                            litersPerTick: '',
                          )
                        : null;
                  })
              : null,
          children: [
            _NumberField(
              scrollKey: keyFor('global.idleWaterCounterReadIntervalSeconds'),
              enabled: enabled,
              label: 'Інтервал зчитування у режимі очікування, с',
              value: draft.globalSettings.idleWaterCounterReadIntervalSeconds,
              error: validation['global.idleWaterCounterReadIntervalSeconds'],
              onChanged: (value) => onChanged(() => draft
                  .globalSettings.idleWaterCounterReadIntervalSeconds = value),
            ),
            _NumberField(
              scrollKey:
                  keyFor('global.wateringWaterCounterReadIntervalSeconds'),
              enabled: enabled,
              label: 'Інтервал зчитування під час поливу, с',
              value:
                  draft.globalSettings.wateringWaterCounterReadIntervalSeconds,
              error:
                  validation['global.wateringWaterCounterReadIntervalSeconds'],
              onChanged: (value) => onChanged(() => draft.globalSettings
                  .wateringWaterCounterReadIntervalSeconds = value),
            ),
            if (magistral == null)
              const Text('Магістральний лічильник води вимкнений.')
            else
              _WaterCounterEditor(
                enabled: enabled,
                prefix: 'magistralWaterCounter',
                counter: magistral,
                validation: validation,
                onChanged: onChanged,
                keyFor: keyFor,
              ),
          ],
        ),
        _Section(
          scrollKey: keyFor('leafWaterCounters'),
          title: 'Лічильники води гілок',
          error: validation['leafWaterCounters'],
          actionLabel: 'Додати лічильник',
          onAction: enabled
              ? () => onChanged(() => draft.leafWaterCounters.add(
                    WaterCounterSettingDraft(
                      pin: '',
                      name: '',
                      litersPerTick: '',
                    ),
                  ))
              : null,
          children: [
            for (var i = 0; i < draft.leafWaterCounters.length; i += 1)
              _RemovableGroup(
                title: 'Лічильник ${i + 1}',
                enabled: enabled,
                onRemove: () =>
                    onChanged(() => draft.leafWaterCounters.removeAt(i)),
                child: _WaterCounterEditor(
                  enabled: enabled,
                  prefix: 'leafWaterCounters.$i',
                  counter: draft.leafWaterCounters[i],
                  validation: validation,
                  onChanged: onChanged,
                  keyFor: keyFor,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ValvesEditor extends StatelessWidget {
  const _ValvesEditor({
    required this.enabled,
    required this.draft,
    required this.validation,
    required this.onChanged,
    required this.keyFor,
  });

  final bool enabled;
  final ControllerSettingsFormDraft draft;
  final ControllerSettingsValidationResult validation;
  final void Function(VoidCallback update) onChanged;
  final GlobalKey Function(String key) keyFor;

  @override
  Widget build(BuildContext context) {
    return _Section(
      scrollKey: keyFor('valves'),
      title: 'Клапани',
      error: validation['valves'],
      actionLabel: 'Додати клапан',
      onAction: enabled
          ? () => onChanged(() => draft.valves.add(
                ValveSettingDraft(
                  pin: '',
                  name: '',
                  soilSensorSlaveAddress: null,
                ),
              ))
          : null,
      children: [
        for (var i = 0; i < draft.valves.length; i += 1)
          _RemovableGroup(
            title: 'Клапан ${i + 1}',
            enabled: enabled,
            onRemove: () => onChanged(() => draft.valves.removeAt(i)),
            child: _FieldColumn(
              children: [
                _NumberField(
                  scrollKey: keyFor('valves.$i.pin'),
                  enabled: enabled,
                  label: 'GPIO pin',
                  value: draft.valves[i].pin,
                  error: validation['valves.$i.pin'],
                  onChanged: (value) =>
                      onChanged(() => draft.valves[i].pin = value),
                ),
                _TextField(
                  scrollKey: keyFor('valves.$i.name'),
                  enabled: enabled,
                  label: 'Назва клапана',
                  value: draft.valves[i].name,
                  error: validation['valves.$i.name'],
                  onChanged: (value) =>
                      onChanged(() => draft.valves[i].name = value),
                ),
                KeyedSubtree(
                  key: keyFor('valves.$i.soilSensorSlaveAddress'),
                  child: DropdownButtonFormField<int>(
                    initialValue: draft.soilSensors.any(
                      (sensor) =>
                          sensor.parsedSlaveAddress ==
                          draft.valves[i].soilSensorSlaveAddress,
                    )
                        ? draft.valves[i].soilSensorSlaveAddress
                        : null,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: 'Привʼязаний датчик вологості',
                      errorText: validation['valves.$i.soilSensorSlaveAddress'],
                    ),
                    items: draft.soilSensors
                        .where((sensor) => sensor.parsedSlaveAddress != null)
                        .map(
                          (sensor) => DropdownMenuItem(
                            value: sensor.parsedSlaveAddress,
                            child: Text(sensor.name),
                          ),
                        )
                        .toList(),
                    onChanged: enabled
                        ? (value) => onChanged(() =>
                            draft.valves[i].soilSensorSlaveAddress = value)
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SoilSensorEditor extends StatelessWidget {
  const _SoilSensorEditor({
    required this.enabled,
    required this.index,
    required this.sensor,
    required this.validation,
    required this.onChanged,
    required this.onRemove,
    required this.keyFor,
  });

  final bool enabled;
  final int index;
  final SoilSensorSettingDraft sensor;
  final ControllerSettingsValidationResult validation;
  final void Function(VoidCallback update) onChanged;
  final VoidCallback onRemove;
  final GlobalKey Function(String key) keyFor;

  @override
  Widget build(BuildContext context) {
    return _RemovableGroup(
      title: 'Датчик ${index + 1}',
      enabled: enabled,
      onRemove: onRemove,
      child: _FieldColumn(
        children: [
          _NumberField(
            scrollKey: keyFor('soilSensors.$index.slaveAddress'),
            enabled: enabled,
            label: 'Modbus address',
            value: sensor.slaveAddress,
            error: validation['soilSensors.$index.slaveAddress'],
            onChanged: (value) => onChanged(() => sensor.slaveAddress = value),
          ),
          _TextField(
            scrollKey: keyFor('soilSensors.$index.name'),
            enabled: enabled,
            label: 'Назва датчика',
            value: sensor.name,
            error: validation['soilSensors.$index.name'],
            onChanged: (value) => onChanged(() => sensor.name = value),
          ),
        ],
      ),
    );
  }
}

class _WaterCounterEditor extends StatelessWidget {
  const _WaterCounterEditor({
    required this.enabled,
    required this.prefix,
    required this.counter,
    required this.validation,
    required this.onChanged,
    required this.keyFor,
  });

  final bool enabled;
  final String prefix;
  final WaterCounterSettingDraft counter;
  final ControllerSettingsValidationResult validation;
  final void Function(VoidCallback update) onChanged;
  final GlobalKey Function(String key) keyFor;

  @override
  Widget build(BuildContext context) {
    return _FieldColumn(
      children: [
        _NumberField(
          scrollKey: keyFor('$prefix.pin'),
          enabled: enabled,
          label: 'GPIO pin',
          value: counter.pin,
          error: validation['$prefix.pin'],
          onChanged: (value) => onChanged(() => counter.pin = value),
        ),
        _TextField(
          scrollKey: keyFor('$prefix.name'),
          enabled: enabled,
          label: 'Назва',
          value: counter.name,
          error: validation['$prefix.name'],
          onChanged: (value) => onChanged(() => counter.name = value),
        ),
        _NumberField(
          scrollKey: keyFor('$prefix.litersPerTick'),
          enabled: enabled,
          label: 'Літрів за один імпульс',
          value: counter.litersPerTick,
          error: validation['$prefix.litersPerTick'],
          decimal: true,
          onChanged: (value) => onChanged(() => counter.litersPerTick = value),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.scrollKey,
    this.error,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final List<Widget> children;
  final GlobalKey? scrollKey;
  final String? error;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: scrollKey,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (actionLabel != null)
                  TextButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon ?? Icons.add),
                    label: Text(actionLabel!),
                  ),
              ],
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 10),
            ...children.expand(
              (child) => [child, const SizedBox(height: 12)],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldColumn extends StatelessWidget {
  const _FieldColumn({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 1) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }
}

class _RemovableGroup extends StatelessWidget {
  const _RemovableGroup({
    required this.title,
    required this.enabled,
    required this.onRemove,
    required this.child,
  });

  final String title;
  final bool enabled;
  final VoidCallback onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(title)),
                IconButton(
                  onPressed: enabled ? onRemove : null,
                  tooltip: 'Видалити',
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.isError,
    required this.onRetry,
  });

  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isError
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text(message)),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Повторити'),
              ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.enabled,
    required this.label,
    required this.value,
    required this.error,
    required this.onChanged,
    this.scrollKey,
    this.decimal = false,
  });

  final bool enabled;
  final String label;
  final String value;
  final String? error;
  final ValueChanged<String> onChanged;
  final GlobalKey? scrollKey;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: scrollKey,
      child: TextFormField(
        enabled: enabled,
        initialValue: value,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          errorText: error,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.enabled,
    required this.label,
    required this.value,
    required this.error,
    required this.onChanged,
    this.scrollKey,
  });

  final bool enabled;
  final String label;
  final String value;
  final String? error;
  final ValueChanged<String> onChanged;
  final GlobalKey? scrollKey;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: scrollKey,
      child: TextFormField(
        enabled: enabled,
        initialValue: value,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
          errorText: error,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _TimeFields extends StatelessWidget {
  const _TimeFields({
    required this.enabled,
    required this.title,
    required this.hour,
    required this.minute,
    required this.error,
    required this.onHourChanged,
    required this.onMinuteChanged,
    this.scrollKey,
  });

  final bool enabled;
  final String title;
  final String? hour;
  final String? minute;
  final String? error;
  final ValueChanged<String> onHourChanged;
  final ValueChanged<String> onMinuteChanged;
  final GlobalKey? scrollKey;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: scrollKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  enabled: enabled,
                  label: 'Година',
                  value: hour ?? '',
                  error: null,
                  onChanged: onHourChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  enabled: enabled,
                  label: 'Хвилина',
                  value: minute ?? '',
                  error: null,
                  onChanged: onMinuteChanged,
                ),
              ),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatSyncedAt(DateTime? value) {
  if (value == null) {
    return 'ще не виконувалось';
  }
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
