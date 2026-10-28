const modbusSlaveAddressError = 'Адреса пристрою має бути від 0 до 255.';
const modbusRegisterAddressError = 'Адреса регістра має бути від 0 до 65535.';
const modbusRegisterValueError = 'Значення має бути від 0 до 65535.';
const modbusRegisterQuantityError = 'Кількість регістрів має бути від 1 до 64.';

int? parseModbusUint8(String text) => _parseRange(text, 0, 255);

int? parseModbusUint16(String text) => _parseRange(text, 0, 65535);

int? parseModbusQuantity(String text) => _parseRange(text, 1, 64);

int? _parseRange(String text, int min, int max) {
  final value = int.tryParse(text.trim());
  return value != null && value >= min && value <= max ? value : null;
}
