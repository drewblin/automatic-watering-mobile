import 'dart:async';

import '../../app/app_state.dart';
import '../../app/app_state_store.dart';
import '../local_controller/local_controller_api_client.dart';
import 'controller_settings.dart';
import 'controller_settings_repository.dart';
import 'device_objects.dart';

enum ControllerSettingsSaveFlowStatus {
  ready,
  dirty,
  invalid,
  saving,
  rebooting,
  reconnecting,
  reconnected,
  saveFailed,
  reconnectFailed,
}

class ControllerSettingsSaveFlowState {
  const ControllerSettingsSaveFlowState({
    required this.status,
    this.message,
  });

  const ControllerSettingsSaveFlowState.ready()
      : status = ControllerSettingsSaveFlowStatus.ready,
        message = null;

  final ControllerSettingsSaveFlowStatus status;
  final String? message;

  bool get isBusy =>
      status == ControllerSettingsSaveFlowStatus.saving ||
      status == ControllerSettingsSaveFlowStatus.rebooting ||
      status == ControllerSettingsSaveFlowStatus.reconnecting;
}

class ControllerSettingsSaveController {
  ControllerSettingsSaveController({
    required AppStateStore stateStore,
    required ControllerSettingsRepository repository,
    Duration rebootDelay = const Duration(seconds: 4),
    Duration reconnectAttemptDelay = const Duration(seconds: 1),
    Duration reconnectTimeout = const Duration(seconds: 45),
  })  : _stateStore = stateStore,
        _repository = repository,
        _rebootDelay = rebootDelay,
        _reconnectAttemptDelay = reconnectAttemptDelay,
        _reconnectTimeout = reconnectTimeout;

  final AppStateStore _stateStore;
  final ControllerSettingsRepository _repository;
  final Duration _rebootDelay;
  final Duration _reconnectAttemptDelay;
  final Duration _reconnectTimeout;

  final _controller =
      StreamController<ControllerSettingsSaveFlowState>.broadcast(sync: true);

  Stream<ControllerSettingsSaveFlowState> get states => _controller.stream;

  Future<bool> save(ControllerSettings settings) async {
    final hub = _stateStore.state.readyWateringHub;
    _emit(const ControllerSettingsSaveFlowState(
      status: ControllerSettingsSaveFlowStatus.saving,
      message: 'Зберігаємо налаштування...',
    ));
    try {
      await _repository.saveSettings(hub, settings);
    } on LocalControllerApiException catch (error) {
      _emit(ControllerSettingsSaveFlowState(
        status: ControllerSettingsSaveFlowStatus.saveFailed,
        message: _saveErrorMessage(error),
      ));
      return false;
    }

    _emit(const ControllerSettingsSaveFlowState(
      status: ControllerSettingsSaveFlowStatus.rebooting,
      message: 'Контролер перезавантажується...',
    ));
    await Future<void>.delayed(_rebootDelay);

    _emit(const ControllerSettingsSaveFlowState(
      status: ControllerSettingsSaveFlowStatus.reconnecting,
      message: 'Відновлюємо зʼєднання з контролером...',
    ));

    final deadline = DateTime.now().add(_reconnectTimeout);
    Object? lastError;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final refreshed = await _repository.syncSettings(hub);
        _stateStore.setState(
          _stateStore.state.copyWith(
            startupStatus: AppStartupStatus.ready,
            settings: refreshed,
            deviceObjects: buildDeviceObjects(
              wateringHubId: hub.id,
              settings: refreshed.settings,
            ),
          ),
        );
        _emit(const ControllerSettingsSaveFlowState(
          status: ControllerSettingsSaveFlowStatus.reconnected,
          message: 'Зʼєднання з контролером відновлено',
        ));
        return true;
      } on LocalControllerApiException catch (error) {
        lastError = error;
        if (error.kind == LocalControllerApiErrorKind.tokenInvalid) {
          break;
        }
        await Future<void>.delayed(_reconnectAttemptDelay);
      }
    }

    _emit(ControllerSettingsSaveFlowState(
      status: ControllerSettingsSaveFlowStatus.reconnectFailed,
      message: _reconnectErrorMessage(lastError),
    ));
    return false;
  }

  void dispose() {
    _controller.close();
  }

  void _emit(ControllerSettingsSaveFlowState state) {
    if (!_controller.isClosed) {
      _controller.add(state);
    }
  }
}

String _saveErrorMessage(LocalControllerApiException error) {
  return switch (error.kind) {
    LocalControllerApiErrorKind.tokenInvalid =>
      'Контролер відхилив токен доступу. Потрібне повторне підключення.',
    LocalControllerApiErrorKind.controllerUnavailable =>
      'Контролер тимчасово недоступний. Налаштування не збережено.',
    LocalControllerApiErrorKind.networkUnavailable =>
      'Немає зʼєднання з контролером. Налаштування не збережено.',
    LocalControllerApiErrorKind.tlsCertificate =>
      'Не вдалося перевірити HTTPS-сертифікат контролера.',
    LocalControllerApiErrorKind.unexpectedResponse => error.message,
  };
}

String _reconnectErrorMessage(Object? error) {
  if (error is LocalControllerApiException &&
      error.kind == LocalControllerApiErrorKind.tokenInvalid) {
    return 'Контролер відхилив токен доступу після перезавантаження.';
  }
  return 'Не вдалося відновити зʼєднання з контролером. Спробуйте ще раз.';
}
