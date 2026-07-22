import 'package:flutter/material.dart';

import '../features/onboarding/ble_onboarding_controller.dart';
import '../features/onboarding/ble_onboarding_screen.dart';
import '../features/watering_hubs/watering_hub_state.dart';
import 'app_state.dart';

class AutomaticWateringApp extends StatefulWidget {
  const AutomaticWateringApp({
    required this.appController,
    required this.bleOnboardingController,
    super.key,
  });

  final AppController appController;
  final BleOnboardingController bleOnboardingController;

  @override
  State<AutomaticWateringApp> createState() => _AutomaticWateringAppState();
}

class _AutomaticWateringAppState extends State<AutomaticWateringApp> {
  @override
  void initState() {
    super.initState();
    widget.appController.initialize();
  }

  @override
  void didUpdateWidget(AutomaticWateringApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appController != oldWidget.appController) {
      widget.appController.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Автоматичний полив',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: AnimatedBuilder(
        animation: widget.appController,
        builder: (context, _) {
          return HomeScreen(
            state: widget.appController.state,
            bleOnboardingController: widget.bleOnboardingController,
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.state,
    required this.bleOnboardingController,
    super.key,
  });

  final AppState state;
  final BleOnboardingController bleOnboardingController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Автоматичний полив')),
      body: Center(
        child: switch (state.startupStatus) {
          AppStartupStatus.initializing => const CircularProgressIndicator(),
          AppStartupStatus.failed => _StatusPanel(
              title: 'Помилка сховища',
              subtitle: state.lastError?.toString() ?? 'Невідома помилка',
            ),
          AppStartupStatus.ready => _ReadyStatePanel(
              state: state,
              bleOnboardingController: bleOnboardingController,
            ),
        },
      ),
    );
  }
}

class _ReadyStatePanel extends StatelessWidget {
  const _ReadyStatePanel({
    required this.state,
    required this.bleOnboardingController,
  });

  final AppState state;
  final BleOnboardingController bleOnboardingController;

  @override
  Widget build(BuildContext context) {
    final hub = state.activeWateringHub;
    if (_shouldShowOnboarding) {
      return BleOnboardingScreen(
        controller: bleOnboardingController,
      );
    }

    final readyHub = hub!;
    return _StatusPanel(
      title: readyHub.displayName,
      subtitle: 'Стан контролера: ${state.connectionState.label}',
    );
  }

  bool get _shouldShowOnboarding {
    final hub = state.activeWateringHub;
    if (hub == null) {
      return true;
    }
    return !hub.isOnboardingComplete || hub.apiAccessToken == null;
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

extension on WateringHubConnectionState {
  String get label {
    return switch (this) {
      WateringHubConnectionState.noDevice => 'пристрій не додано',
      WateringHubConnectionState.offline => 'офлайн',
      WateringHubConnectionState.connecting => 'підключення',
      WateringHubConnectionState.ipPending => 'очікування IP-адреси',
      WateringHubConnectionState.checkingLocalHttps =>
        'перевірка локального HTTPS',
      WateringHubConnectionState.online => 'онлайн',
      WateringHubConnectionState.httpsUnavailable => 'HTTPS недоступний',
      WateringHubConnectionState.tokenInvalid => 'token недійсний',
      WateringHubConnectionState.requiresBleRecovery =>
        'потрібне відновлення через BLE',
      WateringHubConnectionState.reconnectingBle => 'повторне BLE-підключення',
    };
  }
}
