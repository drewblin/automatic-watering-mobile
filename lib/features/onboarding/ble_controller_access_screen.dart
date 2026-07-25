import 'package:flutter/material.dart';

import 'ble_controller_access_widgets.dart';
import 'ble_onboarding_state.dart';
import 'ble_onboarding_step_scaffold.dart';
import 'ble_pairing_widgets.dart';

class BleControllerAccessScreen extends StatefulWidget {
  const BleControllerAccessScreen({
    required this.state,
    required this.onBootstrap,
    required this.onBackToWifi,
    super.key,
  });

  final BleOnboardingState state;
  final VoidCallback onBootstrap;
  final VoidCallback onBackToWifi;

  @override
  State<BleControllerAccessScreen> createState() =>
      _BleControllerAccessScreenState();
}

class _BleControllerAccessScreenState extends State<BleControllerAccessScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrapAccessIfReady();
  }

  @override
  void didUpdateWidget(BleControllerAccessScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state is! AccessSetupReady) {
      _bootstrapAccessIfReady();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BleOnboardingStepScaffold(
      state: widget.state,
      children: [
        BleSelectedDeviceSummary(device: widget.state.selectedDevice!),
        BleControllerAccessStep(
          state: widget.state,
          onBootstrap: widget.onBootstrap,
          onBackToWifi: widget.onBackToWifi,
        ),
      ],
    );
  }

  void _bootstrapAccessIfReady() {
    if (widget.state is! AccessSetupReady) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.state is! AccessSetupReady) {
        return;
      }
      widget.onBootstrap();
    });
  }
}
