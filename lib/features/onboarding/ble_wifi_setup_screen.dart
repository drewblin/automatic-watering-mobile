import 'package:flutter/material.dart';

import 'ble_onboarding_state.dart';
import 'ble_onboarding_step_scaffold.dart';
import 'ble_pairing_widgets.dart';
import 'ble_wifi_widgets.dart';
import 'wifi_provisioning_models.dart';

class BleWifiSetupScreen extends StatelessWidget {
  const BleWifiSetupScreen({
    required this.state,
    required this.onUsePhoneWifi,
    required this.onReadCurrentSettings,
    required this.onSave,
    required this.onCredentialsChanged,
    required this.onRetryReconnect,
    super.key,
  });

  final BleOnboardingState state;
  final VoidCallback onUsePhoneWifi;
  final VoidCallback onReadCurrentSettings;
  final ValueChanged<WifiCredentials> onSave;
  final ValueChanged<WifiCredentials> onCredentialsChanged;
  final VoidCallback onRetryReconnect;

  @override
  Widget build(BuildContext context) {
    return BleOnboardingStepScaffold(
      state: state,
      children: [
        BleSelectedDeviceSummary(device: state.selectedDevice!),
        BleWifiProvisioningStep(
          state: state,
          onUsePhoneWifi: onUsePhoneWifi,
          onReadCurrentSettings: onReadCurrentSettings,
          onSave: onSave,
          onCredentialsChanged: onCredentialsChanged,
          onRetryReconnect: onRetryReconnect,
        ),
      ],
    );
  }
}
