import 'package:flutter/material.dart';

import 'ble_onboarding_state.dart';
import 'ble_onboarding_state_banner.dart';

class BleOnboardingStepScaffold extends StatelessWidget {
  const BleOnboardingStepScaffold({
    required this.state,
    required this.children,
    super.key,
  });

  final BleOnboardingState state;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Додати контролер', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        BleOnboardingStateBanner(state: state),
        for (final child in children) ...[
          const SizedBox(height: 16),
          child,
        ],
      ],
    );
  }
}
