import '../../core/json_helpers.dart';

class ModbusRegisterReadRequest {
  const ModbusRegisterReadRequest({
    required this.slaveAddress,
    required this.registerAddress,
    required this.quantity,
  });

  final int slaveAddress;
  final int registerAddress;
  final int quantity;

  Map<String, Object?> toJson() => {
        'slaveAddress': slaveAddress,
        'registerAddress': registerAddress,
        'quantity': quantity,
      };
}

class ModbusRegisterReadResult {
  ModbusRegisterReadResult({
    required this.status,
    required this.slaveAddress,
    required this.registerAddress,
    required this.quantity,
    required List<int> values,
  }) : values = List.unmodifiable(values);

  final int status;
  final int slaveAddress;
  final int registerAddress;
  final int quantity;
  final List<int> values;

  factory ModbusRegisterReadResult.fromJson(Map<String, Object?> json) {
    return ModbusRegisterReadResult(
      status: readInt(json['status'], 'status'),
      slaveAddress: readInt(json['slaveAddress'], 'slaveAddress'),
      registerAddress: readInt(json['registerAddress'], 'registerAddress'),
      quantity: readInt(json['quantity'], 'quantity'),
      values:
          readList(json['values'], 'values', (item) => readInt(item, 'value')),
    );
  }
}
