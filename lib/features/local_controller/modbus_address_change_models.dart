class ModbusAddressChangeRequest {
  const ModbusAddressChangeRequest({
    required this.currentAddress,
    required this.newAddress,
    required this.registerAddress,
    this.saveRegisterAddress,
    this.saveValue,
  });

  final int currentAddress;
  final int newAddress;
  final int registerAddress;
  final int? saveRegisterAddress;
  final int? saveValue;

  Map<String, Object?> toJson() {
    return {
      'currentAddress': currentAddress,
      'newAddress': newAddress,
      'registerAddress': registerAddress,
      if (saveRegisterAddress != null)
        'saveRegisterAddress': saveRegisterAddress,
      if (saveValue != null) 'saveValue': saveValue,
    };
  }
}

class ModbusAddressChangeResult {
  const ModbusAddressChangeResult({
    required this.currentAddress,
    required this.newAddress,
    required this.registerAddress,
  });

  final int currentAddress;
  final int newAddress;
  final int registerAddress;
}
