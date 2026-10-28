import 'package:flutter/foundation.dart';

import '../../../app/app_state_store.dart';
import '../../local_controller/local_controller_api_client.dart';
import '../../local_controller/modbus_register_read_models.dart';

enum ModbusRegisterReadStatus { idle, submitting, success, failure }

@immutable
class ModbusRegisterReadState {
  const ModbusRegisterReadState({
    required this.status,
    required this.message,
    required this.result,
  });

  const ModbusRegisterReadState.idle()
      : status = ModbusRegisterReadStatus.idle,
        message = null,
        result = null;

  final ModbusRegisterReadStatus status;
  final String? message;
  final ModbusRegisterReadResult? result;

  bool get isSubmitting => status == ModbusRegisterReadStatus.submitting;
}

class ModbusRegisterReadController extends ChangeNotifier {
  ModbusRegisterReadController({
    required AppStateStore stateStore,
    required LocalControllerApiClient apiClient,
  })  : _stateStore = stateStore,
        _apiClient = apiClient;

  final AppStateStore _stateStore;
  final LocalControllerApiClient _apiClient;
  ModbusRegisterReadState _state = const ModbusRegisterReadState.idle();
  bool _disposed = false;

  ModbusRegisterReadState get state => _state;

  Future<bool> submit({
    required String slaveAddressText,
    required String registerAddressText,
    required String quantityText,
  }) async {
    if (_disposed || _state.isSubmitting) return false;

    final access = _stateStore.state.activeWateringHub?.readyAccess;
    if (access == null) {
      _setState(const ModbusRegisterReadState(
        status: ModbusRegisterReadStatus.failure,
        message: 'Активний контролер ще не налаштовано.',
        result: null,
      ));
      return false;
    }

    final slaveAddress = int.tryParse(slaveAddressText.trim());
    if (slaveAddress == null || slaveAddress < 0 || slaveAddress > 255) {
      return _rejectRequest('Адреса пристрою має бути від 0 до 255.');
    }
    final registerAddress = int.tryParse(registerAddressText.trim());
    if (registerAddress == null ||
        registerAddress < 0 ||
        registerAddress > 65535) {
      return _rejectRequest('Адреса регістра має бути від 0 до 65535.');
    }
    final quantity = int.tryParse(quantityText.trim());
    if (quantity == null || quantity < 1 || quantity > 64) {
      return _rejectRequest('Кількість регістрів має бути від 1 до 64.');
    }

    _setState(const ModbusRegisterReadState(
      status: ModbusRegisterReadStatus.submitting,
      message: null,
      result: null,
    ));
    try {
      final result = await _apiClient.readModbusRegisters(
        hostname: access.hostname,
        apiAccessToken: access.apiAccessToken,
        request: ModbusRegisterReadRequest(
          slaveAddress: slaveAddress,
          registerAddress: registerAddress,
          quantity: quantity,
        ),
      );
      if (_disposed) return false;
      _setState(ModbusRegisterReadState(
        status: ModbusRegisterReadStatus.success,
        message: null,
        result: result,
      ));
      return true;
    } catch (_) {
      _setState(const ModbusRegisterReadState(
        status: ModbusRegisterReadStatus.failure,
        message: 'Не вдалося прочитати регістри.',
        result: null,
      ));
    }
    return false;
  }

  bool _rejectRequest(String message) {
    _setState(ModbusRegisterReadState(
      status: ModbusRegisterReadStatus.failure,
      message: message,
      result: null,
    ));
    return false;
  }

  void _setState(ModbusRegisterReadState state) {
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
