import 'package:flutter/foundation.dart';

import '../../../app/app_state_store.dart';
import '../../local_controller/local_controller_api_client.dart';
import '../../local_controller/modbus_register_write_models.dart';
import '../modbus_register_validation.dart';

enum ModbusRegisterWriteStatus {
  idle,
  invalid,
  submitting,
  success,
  failure,
}

@immutable
class ModbusRegisterWriteState {
  const ModbusRegisterWriteState({
    required this.status,
    this.message,
  });

  const ModbusRegisterWriteState.idle()
      : status = ModbusRegisterWriteStatus.idle,
        message = null;

  final ModbusRegisterWriteStatus status;
  final String? message;

  bool get isSubmitting => status == ModbusRegisterWriteStatus.submitting;
}

class ModbusRegisterWriteController extends ChangeNotifier {
  ModbusRegisterWriteController({
    required AppStateStore stateStore,
    required LocalControllerApiClient apiClient,
  })  : _stateStore = stateStore,
        _apiClient = apiClient;

  final AppStateStore _stateStore;
  final LocalControllerApiClient _apiClient;
  ModbusRegisterWriteState _state = const ModbusRegisterWriteState.idle();
  bool _disposed = false;

  ModbusRegisterWriteState get state => _state;

  Future<bool> submit({
    required String slaveAddressText,
    required String registerAddressText,
    required String valueText,
  }) async {
    if (_disposed || _state.isSubmitting) {
      return false;
    }

    final request = _buildRequest(
      slaveAddressText: slaveAddressText,
      registerAddressText: registerAddressText,
      valueText: valueText,
    );
    if (request == null) {
      return false;
    }

    final access = _stateStore.state.activeWateringHub?.readyAccess;
    if (access == null) {
      _setState(const ModbusRegisterWriteState(
        status: ModbusRegisterWriteStatus.failure,
        message: 'Активний контролер ще не налаштовано.',
      ));
      return false;
    }

    _setState(const ModbusRegisterWriteState(
      status: ModbusRegisterWriteStatus.submitting,
    ));

    try {
      final result = await _apiClient.writeModbusRegister(
        hostname: access.hostname,
        apiAccessToken: access.apiAccessToken,
        request: request,
      );
      if (_disposed) return false;
      _setState(ModbusRegisterWriteState(
        status: ModbusRegisterWriteStatus.success,
        message:
            'Значення ${result.value} записано в регістр ${result.registerAddress} пристрою ${result.slaveAddress}.',
      ));
      return true;
    } on LocalControllerApiException {
      _setState(const ModbusRegisterWriteState(
        status: ModbusRegisterWriteStatus.failure,
        message: 'Не вдалося записати значення в регістр.',
      ));
      return false;
    } catch (_) {
      _setState(const ModbusRegisterWriteState(
        status: ModbusRegisterWriteStatus.failure,
        message: 'Не вдалося звʼязатися з контролером.',
      ));
      return false;
    }
  }

  void clearValidationMessage() {
    if (_state.status != ModbusRegisterWriteStatus.invalid) {
      return;
    }
    _setState(const ModbusRegisterWriteState.idle());
  }

  ModbusRegisterWriteRequest? _buildRequest({
    required String slaveAddressText,
    required String registerAddressText,
    required String valueText,
  }) {
    final slaveAddress = parseModbusUint8(slaveAddressText);
    if (slaveAddress == null) {
      _setState(const ModbusRegisterWriteState(
        status: ModbusRegisterWriteStatus.invalid,
        message: modbusSlaveAddressError,
      ));
      return null;
    }

    final registerAddress = parseModbusUint16(registerAddressText);
    if (registerAddress == null) {
      _setState(const ModbusRegisterWriteState(
        status: ModbusRegisterWriteStatus.invalid,
        message: modbusRegisterAddressError,
      ));
      return null;
    }

    final value = parseModbusUint16(valueText);
    if (value == null) {
      _setState(const ModbusRegisterWriteState(
        status: ModbusRegisterWriteStatus.invalid,
        message: modbusRegisterValueError,
      ));
      return null;
    }

    return ModbusRegisterWriteRequest(
      slaveAddress: slaveAddress,
      registerAddress: registerAddress,
      value: value,
    );
  }

  void _setState(ModbusRegisterWriteState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
