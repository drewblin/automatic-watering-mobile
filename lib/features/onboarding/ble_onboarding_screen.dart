import 'package:flutter/material.dart';

import 'ble_onboarding_controller.dart';
import 'ble_controller_access_screen.dart';
import 'ble_discovery_screen.dart';
import 'ble_onboarding_state.dart';
import 'ble_pairing_screen.dart';
import 'ble_wifi_setup_screen.dart';

class BleOnboardingScreen extends StatefulWidget {
  const BleOnboardingScreen({
    required this.controller,
    required this.onCompleted,
    super.key,
  });

  final BleOnboardingController controller;
  final Future<void> Function() onCompleted;

  @override
  State<BleOnboardingScreen> createState() => _BleOnboardingScreenState();
}

class _BleOnboardingScreenState extends State<BleOnboardingScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_completeOnboardingIfReady);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.controller.checkAvailability();
    });
  }

  @override
  void didUpdateWidget(BleOnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller.removeListener(_completeOnboardingIfReady);
    widget.controller.addListener(_completeOnboardingIfReady);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_completeOnboardingIfReady);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;

        return _screenForState(state);
      },
    );
  }

  Widget _screenForState(BleOnboardingState state) {
    return switch (state) {
      CheckingBluetooth() ||
      BluetoothUnavailable() ||
      ReadyToScan() ||
      DiscoveringDevices() =>
        BleDiscoveryScreen(
          state: state,
          onRequestPermissions: widget.controller.requestPermissions,
          onScan: widget.controller.startScan,
          onSelect: widget.controller.selectDevice,
        ),
      DeviceSelected() ||
      ConnectingDevice() ||
      AwaitingPairingPasskey() ||
      PairingInProgress() =>
        BlePairingScreen(
          state: state,
          onConnect: widget.controller.connectSelectedDevice,
        ),
      ReadingWifiSettings() ||
      WifiCredentialsFormReady() ||
      SavingWifiSettings() ||
      WaitingForControllerReboot() ||
      ReconnectingAfterReboot() ||
      ReconnectAfterRebootBlocked() =>
        BleWifiSetupScreen(
          state: state,
          onUsePhoneWifi: widget.controller.useCurrentPhoneWifi,
          onReadCurrentSettings: widget.controller.readCurrentWifiSettings,
          onSave: widget.controller.saveWifiSettings,
          onSkip: widget.controller.skipWifiSettings,
          onCredentialsChanged: widget.controller.updateWifiCredentials,
          onRetryReconnect: widget.controller.retryWifiReconnect,
        ),
      AccessSetupReady() ||
      ReadingControllerAccess() ||
      CheckingLocalHttpsAccess() ||
      ControllerIpPending() ||
      ControllerAccessFailed() ||
      ControllerAccessReady() =>
        BleControllerAccessScreen(
          state: state,
          onBootstrap: widget.controller.bootstrapControllerAccess,
          onBackToWifi: widget.controller.returnToWifiProvisioning,
        ),
    };
  }

  void _completeOnboardingIfReady() {
    if (widget.controller.state is! ControllerAccessReady) {
      return;
    }
    widget.controller.removeListener(_completeOnboardingIfReady);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await widget.onCompleted();
    });
  }
}
