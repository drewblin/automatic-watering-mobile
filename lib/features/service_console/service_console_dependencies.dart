import '../local_controller/diagnostics_log.dart';
import 'ble_logs/ble_controller_logs_controller.dart';

class ServiceConsoleDependencies {
  const ServiceConsoleDependencies({
    required this.diagnosticsLog,
    required this.bleLogsController,
  });

  final DiagnosticsLog diagnosticsLog;
  final BleControllerLogsController bleLogsController;
}
