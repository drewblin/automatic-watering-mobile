import 'package:flutter/material.dart';

import '../ble/ble_models.dart';
import 'ble_discovery_widgets.dart';
import 'ble_onboarding_state.dart';
import 'ble_onboarding_step_scaffold.dart';

class BleDiscoveryScreen extends StatelessWidget {
  const BleDiscoveryScreen({
    required this.state,
    required this.onRequestPermissions,
    required this.onScan,
    required this.onSelect,
    super.key,
  });

  final BleOnboardingState state;
  final VoidCallback onRequestPermissions;
  final VoidCallback onScan;
  final ValueChanged<BleDiscoveredDevice> onSelect;

  @override
  Widget build(BuildContext context) {
    return BleOnboardingStepScaffold(
      state: state,
      children: [
        BleScanStep(
          state: state,
          onRequestPermissions: onRequestPermissions,
          onScan: onScan,
        ),
        if (_showsDeviceSelection)
          BleDeviceSelectionStep(
            state: state,
            onSelect: onSelect,
          ),
      ],
    );
  }

  bool get _showsDeviceSelection {
    return state is ReadyToScan || state is DiscoveringDevices;
  }
}
