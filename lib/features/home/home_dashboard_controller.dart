import 'package:flutter/foundation.dart';

import '../../app/app_state.dart';
import '../../app/app_state_store.dart';
import '../controller_settings/controller_settings.dart';
import '../controller_settings/controller_settings_repository.dart';
import '../controller_settings/device_objects.dart';
import '../local_controller/local_controller_api_client.dart';
import '../sensors/sensor_metric.dart';

enum DashboardRefreshStatus {
  idle,
  loading,
  loaded,
  failed,
}

enum ManualValveCommandStatus {
  idle,
  sending,
  sent,
  failed,
}

class ManualValveCommandState {
  const ManualValveCommandState({
    required this.status,
    this.valvePin,
    this.message,
  });

  const ManualValveCommandState.idle()
      : status = ManualValveCommandStatus.idle,
        valvePin = null,
        message = null;

  final ManualValveCommandStatus status;
  final int? valvePin;
  final String? message;
}

class HomeDashboardController extends ChangeNotifier {
  HomeDashboardController({
    required AppStateStore stateStore,
    required ControllerSettingsRepository settingsRepository,
    required LocalControllerApiClient apiClient,
  })  : _stateStore = stateStore,
        _settingsRepository = settingsRepository,
        _apiClient = apiClient;

  final AppStateStore _stateStore;
  final ControllerSettingsRepository _settingsRepository;
  final LocalControllerApiClient _apiClient;

  DashboardRefreshStatus _refreshStatus = DashboardRefreshStatus.idle;
  ManualValveCommandState _manualValveState =
      const ManualValveCommandState.idle();
  List<SensorMetric> _metrics = const [];
  DateTime? _lastMetricsSyncedAt;
  String? _refreshErrorMessage;

  DashboardRefreshStatus get refreshStatus => _refreshStatus;
  ManualValveCommandState get manualValveState => _manualValveState;
  List<SensorMetric> get metrics => _metrics;
  DateTime? get lastMetricsSyncedAt => _lastMetricsSyncedAt;
  String? get refreshErrorMessage => _refreshErrorMessage;

  bool get isRefreshing => _refreshStatus == DashboardRefreshStatus.loading;

  Future<void> refresh() async {
    final access = _stateStore.state.readyWateringHubAccess;
    final hub = access.hub;
    _setRefreshState(DashboardRefreshStatus.loading);
    try {
      final settings = await _settingsRepository.syncSettings(access);
      final deviceObjects = buildDeviceObjects(
        wateringHubId: hub.id,
        settings: settings.settings,
      );
      _stateStore.setState(
        _stateStore.state.copyWith(
          startupStatus: AppStartupStatus.ready,
          settings: settings,
          deviceObjects: deviceObjects,
        ),
      );

      final rawMetrics = await _apiClient.getSensorMetrics(
        ipAddress: access.ipAddress,
        apiAccessToken: access.apiAccessToken,
      );
      _metrics = _mapMetrics(rawMetrics, deviceObjects);
      _lastMetricsSyncedAt = DateTime.now().toUtc();
      _refreshErrorMessage = null;
      _setRefreshState(DashboardRefreshStatus.loaded);
    } on LocalControllerApiException catch (error) {
      _refreshErrorMessage = _refreshErrorFor(error);
      _setRefreshState(DashboardRefreshStatus.failed);
    }
  }

  Future<bool> openValveForTime({
    required ValveSetting valve,
    required int seconds,
    required ControllerSettings settings,
  }) async {
    final maxSeconds =
        settings.globalSettings.maximumManualValveOpenTimeSeconds;
    if (seconds <= 0) {
      _setManualValveState(
        ManualValveCommandState(
          status: ManualValveCommandStatus.failed,
          valvePin: valve.pin,
          message: 'Час відкриття має бути більшим за 0 с.',
        ),
      );
      return false;
    }
    if (seconds > maxSeconds) {
      _setManualValveState(
        ManualValveCommandState(
          status: ManualValveCommandStatus.failed,
          valvePin: valve.pin,
          message: 'Час відкриття не може перевищувати $maxSeconds с.',
        ),
      );
      return false;
    }

    final access = _stateStore.state.readyWateringHubAccess;
    _setManualValveState(
      ManualValveCommandState(
        status: ManualValveCommandStatus.sending,
        valvePin: valve.pin,
      ),
    );
    try {
      await _apiClient.openValveForTime(
        ipAddress: access.ipAddress,
        apiAccessToken: access.apiAccessToken,
        pin: valve.pin,
        seconds: seconds,
      );
      _setManualValveState(
        ManualValveCommandState(
          status: ManualValveCommandStatus.sent,
          valvePin: valve.pin,
          message: 'Команду відправлено',
        ),
      );
      return true;
    } on LocalControllerApiException catch (error) {
      _setManualValveState(
        ManualValveCommandState(
          status: ManualValveCommandStatus.failed,
          valvePin: valve.pin,
          message: _manualValveErrorFor(error),
        ),
      );
      return false;
    }
  }

  void resetManualValveState() {
    _setManualValveState(const ManualValveCommandState.idle());
  }

  List<SensorMetric> _mapMetrics(
    List<ControllerSensorMetric> rawMetrics,
    List<DeviceObject> deviceObjects,
  ) {
    return rawMetrics.map((metric) {
      final deviceObjectId = _deviceObjectIdForMetric(metric, deviceObjects);
      if (deviceObjectId == null) {
        throw const LocalControllerApiException();
      }
      return SensorMetric.fromControllerMetric(
        metric: metric,
        deviceObjectId: deviceObjectId,
      );
    }).toList(growable: false);
  }

  String? _deviceObjectIdForMetric(
    ControllerSensorMetric metric,
    List<DeviceObject> deviceObjects,
  ) {
    for (final object in deviceObjects) {
      if (object case SoilSensorObject(:final setting)
          when (metric.sensorType == SensorType.soilHumidity ||
                  metric.sensorType == SensorType.soilTemperature) &&
              setting.slaveAddress == metric.sensorId) {
        return object.id;
      }
      if (object case PressureSensorObject(:final setting)
          when metric.sensorType == SensorType.pressure &&
              setting.slaveAddress == metric.sensorId) {
        return object.id;
      }
      if (object case WaterCounterObject(:final setting)
          when metric.sensorType == SensorType.waterCounter &&
              setting.pin == metric.sensorId) {
        return object.id;
      }
    }
    return null;
  }

  void _setRefreshState(DashboardRefreshStatus status) {
    _refreshStatus = status;
    notifyListeners();
  }

  void _setManualValveState(ManualValveCommandState state) {
    _manualValveState = state;
    notifyListeners();
  }
}

String _refreshErrorFor(LocalControllerApiException _) =>
    'Помилка комунікації з контролером.';

String _manualValveErrorFor(LocalControllerApiException _) {
  return 'Помилка комунікації з контролером.';
}
