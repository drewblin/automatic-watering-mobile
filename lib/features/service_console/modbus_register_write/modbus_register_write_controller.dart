import 'package:flutter/foundation.dart';

import '../../../app/app_state_store.dart';
import '../../local_controller/local_controller_api_client.dart';
import '../../local_controller/modbus_register_write_models.dart';

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

  ModbusRegisterWriteState get state => _state;

  Future<bool> submit({
    required String slaveAddressText,
    required String registerAddressText,
    required String valueText,
  }) async {
    if (_state.isSubmitting) {
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
    final slaveAddress = _readUint8(slaveAddressText);
    if (slaveAddress == null) {
      _setState(const ModbusRegisterWriteState(
        status: ModbusRegisterWriteStatus.invalid,
        message: 'Адреса пристрою має бути від 0 до 255.',
      ));
      return null;
    }

    final registerAddress = _readUint16(registerAddressText);
    if (registerAddress == null) {
      _setState(const ModbusRegisterWriteState(
        status: ModbusRegisterWriteStatus.invalid,
        message: 'Адреса регістра має бути від 0 до 65535.',
      ));
      return null;
    }

    final value = _readUint16(valueText);
    if (value == null) {
      _setState(const ModbusRegisterWriteState(
        status: ModbusRegisterWriteStatus.invalid,
        message: 'Значення має бути від 0 до 65535.',
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
    _state = state;
    notifyListeners();
  }
}

int? _readUint8(String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < 0 || parsed > 255) {
    return null;
  }
  return parsed;
}

int? _readUint16(String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < 0 || parsed > 65535) {
    return null;
  }
  return parsed;
}
