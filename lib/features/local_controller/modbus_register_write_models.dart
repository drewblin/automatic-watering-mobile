import '../../core/json_helpers.dart';

class ModbusRegisterWriteRequest {
  const ModbusRegisterWriteRequest({
    required this.slaveAddress,
    required this.registerAddress,
    required this.value,
  });

  final int slaveAddress;
  final int registerAddress;
  final int value;

  Map<String, Object?> toJson() => {
        'slaveAddress': slaveAddress,
        'registerAddress': registerAddress,
        'value': value,
      };
}

class ModbusRegisterWriteResult {
  const ModbusRegisterWriteResult({
    required this.status,
    required this.slaveAddress,
    required this.registerAddress,
    required this.value,
  });

  final int status;
  final int slaveAddress;
  final int registerAddress;
  final int value;

  factory ModbusRegisterWriteResult.fromJson(Map<String, Object?> json) {
    return ModbusRegisterWriteResult(
      status: readInt(json['status'], 'status'),
      slaveAddress: readInt(json['slaveAddress'], 'slaveAddress'),
      registerAddress: readInt(json['registerAddress'], 'registerAddress'),
      value: readInt(json['value'], 'value'),
    );
  }
}
