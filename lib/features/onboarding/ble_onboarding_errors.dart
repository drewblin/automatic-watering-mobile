import '../../features/ble/ble_models.dart';
import '../../features/diagnostics/diagnostics_log.dart';
import 'wifi_provisioning_models.dart';

BleConnectionError bleOnboardingBleError({
  required String message,
  required Object error,
  required DiagnosticsLog diagnosticsLog,
}) {
  recordDiagnosticsIssue(
    diagnosticsLog: diagnosticsLog,
    message: message,
    error: error,
  );
  return BleConnectionError(
    message: message,
  );
}

WifiProvisioningError bleOnboardingWifiError({
  required String message,
  required WifiProvisioningOperation operation,
  required Object error,
  required DiagnosticsLog diagnosticsLog,
}) {
  recordDiagnosticsIssue(
    diagnosticsLog: diagnosticsLog,
    message: message,
    error: error,
  );
  return WifiProvisioningError(
    message: message,
    operation: operation,
  );
}
