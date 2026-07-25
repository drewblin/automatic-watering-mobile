import 'package:flutter/material.dart';

import 'ble_onboarding_state.dart';
import 'ble_onboarding_step_scaffold.dart';
import 'ble_pairing_widgets.dart';

class BlePairingScreen extends StatelessWidget {
  const BlePairingScreen({
    required this.state,
    required this.onConnect,
    required this.onPair,
    super.key,
  });

  final BleOnboardingState state;
  final VoidCallback onConnect;
  final ValueChanged<String> onPair;

  @override
  Widget build(BuildContext context) {
    return BleOnboardingStepScaffold(
      state: state,
      children: [
        BleSelectedDeviceSummary(device: state.selectedDevice!),
        BlePairingStep(
          state: state,
          onConnect: onConnect,
          onPair: onPair,
        ),
      ],
    );
  }
}
