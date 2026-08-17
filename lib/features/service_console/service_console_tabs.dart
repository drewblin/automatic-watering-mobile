import 'diagnostics/diagnostics_log_tab.dart';
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
  ];
}
