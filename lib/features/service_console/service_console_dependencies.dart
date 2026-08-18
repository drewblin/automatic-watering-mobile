import '../diagnostics/diagnostics_log.dart';
import 'ble_logs/ble_controller_logs_controller.dart';
import 'modbus_address/modbus_address_change_controller.dart';

class ServiceConsoleDependencies {
  const ServiceConsoleDependencies({
    required this.diagnosticsLog,
    required this.bleLogsController,
    required this.modbusAddressChangeController,
  });

  final DiagnosticsLog diagnosticsLog;
  final BleControllerLogsController bleLogsController;
  final ModbusAddressChangeController modbusAddressChangeController;
}
