import 'ble_logs/ble_logs_tab.dart';
import 'diagnostics/diagnostics_log_tab.dart';
import 'modbus_address/modbus_address_tab.dart';
import 'modbus_register_read/modbus_register_read_tab.dart';
import 'service_console_dependencies.dart';
import 'service_console_tab.dart';

List<ServiceConsoleTab> buildServiceConsoleTabs(
  ServiceConsoleDependencies dependencies,
) {
  return [
    ServiceConsoleTab(
      label: 'Діагностика',
      builder: (_) => DiagnosticsLogTab(
        diagnosticsLog: dependencies.diagnosticsLog,
      ),
    ),
    ServiceConsoleTab(
      label: 'BLE логи',
      builder: (_) => BleLogsTab(
        controller: dependencies.bleLogsController,
      ),
    ),
    ServiceConsoleTab(
      label: 'Modbus регістр',
      builder: (_) => ModbusRegisterWriteTab(
        controller: dependencies.modbusRegisterWriteController,
      ),
    ),
    ServiceConsoleTab(
      label: 'Читання Modbus',
      builder: (_) => ModbusRegisterReadTab(
        key: null,
        controller: dependencies.modbusRegisterReadController,
      ),
    ),
  ];
}
