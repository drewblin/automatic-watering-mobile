import '../../features/ble/ble_models.dart';
import '../../features/local_controller/local_controller_api_client.dart';
import 'ble_onboarding_state.dart';
import 'wifi_provisioning_models.dart';

BleConnectionError bleOnboardingBleError(String message, Object error) {
  return BleConnectionError(
    message: message,
    technicalReason: safeOnboardingTechnicalReason(error),
  );
}

WifiProvisioningError bleOnboardingWifiError({
  required String message,
  required WifiProvisioningOperation operation,
  required Object error,
}) {
  return WifiProvisioningError(
    message: message,
    technicalReason: safeOnboardingTechnicalReason(error),
    operation: operation,
  );
}

ControllerAccessFailureKind controllerAccessFailureKindFrom(
  LocalControllerApiErrorKind kind,
) {
  return switch (kind) {
    LocalControllerApiErrorKind.networkUnavailable =>
      ControllerAccessFailureKind.networkUnavailable,
    LocalControllerApiErrorKind.tlsCertificate =>
      ControllerAccessFailureKind.tlsCertificate,
    LocalControllerApiErrorKind.tokenInvalid =>
      ControllerAccessFailureKind.tokenInvalid,
    LocalControllerApiErrorKind.controllerUnavailable =>
      ControllerAccessFailureKind.controllerUnavailable,
    LocalControllerApiErrorKind.unexpectedResponse =>
      ControllerAccessFailureKind.unexpectedResponse,
  };
}

String controllerAccessMessage(ControllerAccessFailureKind kind) {
  return switch (kind) {
    ControllerAccessFailureKind.ipPending =>
      'Контролер ще не отримав IP-адресу Wi-Fi. Зачекайте або поверніться до Wi-Fi налаштувань.',
    ControllerAccessFailureKind.tokenInvalid =>
      'Контролер відхилив токен доступу. Потрібно повторно прочитати token через BLE.',
    ControllerAccessFailureKind.timeout ||
    ControllerAccessFailureKind.networkUnavailable =>
      'Не вдалося підключитися до локального HTTPS API. Перевірте, що телефон у тій самій Wi-Fi мережі.',
    ControllerAccessFailureKind.tlsCertificate =>
      'TLS-сертифікат контролера не пройшов перевірку fingerprint.',
    ControllerAccessFailureKind.controllerUnavailable =>
      'Контролер тимчасово недоступний через HTTPS API.',
    ControllerAccessFailureKind.unexpectedResponse =>
      'Контролер повернув неочікувану відповідь на GET /api/settings.',
  };
}

String safeOnboardingTechnicalReason(Object error) {
  final raw = error.toString();
  if (raw.length <= 240) {
    return raw;
  }
  return '${raw.substring(0, 240)}...';
}
