class ModbusAddressChangeRequest {
  const ModbusAddressChangeRequest({
    required this.currentAddress,
    required this.newAddress,
  });

  final int currentAddress;
  final int newAddress;

  Map<String, Object?> toJson() => {
        'currentAddress': currentAddress,
        'newAddress': newAddress,
      };
}

class ModbusAddressChangeResult {
  const ModbusAddressChangeResult({
    required this.currentAddress,
    required this.newAddress,
  });

  final int currentAddress;
  final int newAddress;
}
