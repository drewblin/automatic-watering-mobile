import '../diagnostics/diagnostics_log.dart';
import 'ble_logs/ble_controller_logs_controller.dart';
import 'modbus_register_write/modbus_register_write_controller.dart';
import 'modbus_register_read/modbus_register_read_controller.dart';

class ServiceConsoleDependencies {
  const ServiceConsoleDependencies({
    required this.diagnosticsLog,
    required this.bleLogsController,
    required this.modbusRegisterWriteController,
    required this.modbusRegisterReadController,
  });

  final DiagnosticsLog diagnosticsLog;
  final BleControllerLogsController bleLogsController;
  final ModbusRegisterWriteController modbusRegisterWriteController;
  final ModbusRegisterReadController modbusRegisterReadController;
}
