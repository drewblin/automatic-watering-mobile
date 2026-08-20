import 'package:flutter/foundation.dart';

import '../../local_controller/local_controller_api_client.dart';
import '../../local_controller/modbus_address_change_models.dart';
import '../../watering_hubs/watering_hub.dart';

typedef ActiveControllerAccessProvider = ReadyWateringHubAccess? Function();

enum ModbusAddressChangeStatus {
  idle,
  invalid,
  submitting,
  success,
  failure,
}

@immutable
class ModbusAddressChangeState {
  const ModbusAddressChangeState({
    required this.status,
    this.message,
  });

  const ModbusAddressChangeState.idle()
      : status = ModbusAddressChangeStatus.idle,
        message = null;

  final ModbusAddressChangeStatus status;
  final String? message;

  bool get isSubmitting => status == ModbusAddressChangeStatus.submitting;
}

class ModbusAddressChangeController extends ChangeNotifier {
  ModbusAddressChangeController({
    required LocalControllerApiClient apiClient,
    required ActiveControllerAccessProvider activeControllerAccessProvider,
  })  : _apiClient = apiClient,
        _activeControllerAccessProvider = activeControllerAccessProvider;

  final LocalControllerApiClient _apiClient;
  final ActiveControllerAccessProvider _activeControllerAccessProvider;
  ModbusAddressChangeState _state = const ModbusAddressChangeState.idle();

  ModbusAddressChangeState get state => _state;

  Future<bool> submit({
    required String currentAddressText,
    required String newAddressText,
    required String registerAddressText,
    required String saveRegisterAddressText,
    required String saveValueText,
  }) async {
    if (_state.isSubmitting) {
      return false;
    }

    final request = _buildRequest(
      currentAddressText: currentAddressText,
      newAddressText: newAddressText,
      registerAddressText: registerAddressText,
      saveRegisterAddressText: saveRegisterAddressText,
      saveValueText: saveValueText,
    );
    if (request == null) {
      return false;
    }

    final access = _activeControllerAccessProvider();
    if (access == null) {
      _setState(const ModbusAddressChangeState(
        status: ModbusAddressChangeStatus.failure,
        message: 'Активний контролер ще не налаштовано.',
      ));
      return false;
    }

    _setState(const ModbusAddressChangeState(
      status: ModbusAddressChangeStatus.submitting,
    ));

    try {
      final result = await _apiClient.changeModbusAddress(
        ipAddress: access.ipAddress,
        apiAccessToken: access.apiAccessToken,
        request: request,
      );
      _setState(ModbusAddressChangeState(
        status: ModbusAddressChangeStatus.success,
        message:
            'Адресу ${result.currentAddress} змінено на ${result.newAddress}.',
      ));
      return true;
    } on LocalControllerApiException {
      _setState(const ModbusAddressChangeState(
        status: ModbusAddressChangeStatus.failure,
        message: 'Контролер повернув помилку.',
      ));
      return false;
    } catch (_) {
      _setState(const ModbusAddressChangeState(
        status: ModbusAddressChangeStatus.failure,
        message: 'Не вдалося звʼязатися з контролером.',
      ));
      return false;
    }
  }

  void clearValidationMessage() {
    if (_state.status != ModbusAddressChangeStatus.invalid) {
      return;
    }
    _setState(const ModbusAddressChangeState.idle());
  }

  ModbusAddressChangeRequest? _buildRequest({
    required String currentAddressText,
    required String newAddressText,
    required String registerAddressText,
    required String saveRegisterAddressText,
    required String saveValueText,
  }) {
    final currentAddress = _readAddress(currentAddressText);
    if (currentAddress == null) {
      _setState(const ModbusAddressChangeState(
        status: ModbusAddressChangeStatus.invalid,
        message: 'Поточна адреса має бути від 1 до 247.',
      ));
      return null;
    }

    final newAddress = _readAddress(newAddressText);
    if (newAddress == null) {
      _setState(const ModbusAddressChangeState(
        status: ModbusAddressChangeStatus.invalid,
        message: 'Нова адреса має бути від 1 до 247.',
      ));
      return null;
    }

    if (currentAddress == newAddress) {
      _setState(const ModbusAddressChangeState(
        status: ModbusAddressChangeStatus.invalid,
        message: 'Нова адреса має відрізнятися від поточної.',
      ));
      return null;
    }

    final registerAddress = _readUint16(registerAddressText);
    if (registerAddress == null) {
      _setState(const ModbusAddressChangeState(
        status: ModbusAddressChangeStatus.invalid,
        message: 'Адреса register має бути від 0 до 65535.',
      ));
      return null;
    }

    final hasSaveRegisterAddress = saveRegisterAddressText.trim().isNotEmpty;
    final hasSaveValue = saveValueText.trim().isNotEmpty;
    if (hasSaveRegisterAddress != hasSaveValue) {
      _setState(const ModbusAddressChangeState(
        status: ModbusAddressChangeStatus.invalid,
        message:
            'Save register address і save value потрібно заповнювати разом.',
      ));
      return null;
    }

    final int? saveRegisterAddress;
    final int? saveValue;
    if (hasSaveRegisterAddress) {
      saveRegisterAddress = _readUint16(saveRegisterAddressText);
      saveValue = _readUint16(saveValueText);
      if (saveRegisterAddress == null || saveValue == null) {
        _setState(const ModbusAddressChangeState(
          status: ModbusAddressChangeStatus.invalid,
          message:
              'Save register address і save value мають бути від 0 до 65535.',
        ));
        return null;
      }
    } else {
      saveRegisterAddress = null;
      saveValue = null;
    }

    return ModbusAddressChangeRequest(
      currentAddress: currentAddress,
      newAddress: newAddress,
      registerAddress: registerAddress,
      saveRegisterAddress: saveRegisterAddress,
      saveValue: saveValue,
    );
  }

  void _setState(ModbusAddressChangeState state) {
    _state = state;
    notifyListeners();
  }
}

int? _readAddress(String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < 1 || parsed > 247) {
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
