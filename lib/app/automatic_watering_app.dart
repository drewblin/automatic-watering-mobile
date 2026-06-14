import 'package:flutter/material.dart';

import '../features/watering_hubs/watering_hub_state.dart';
import 'app_state.dart';

class AutomaticWateringApp extends StatefulWidget {
  const AutomaticWateringApp({
    required this.appController,
    super.key,
  });

  final AppController appController;

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
      title: 'Automatic Watering',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: AnimatedBuilder(
        animation: widget.appController,
        builder: (context, _) {
          return HomeScreen(state: widget.appController.state);
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Automatic Watering')),
      body: Center(
        child: switch (state.startupStatus) {
          AppStartupStatus.initializing => const CircularProgressIndicator(),
          AppStartupStatus.failed => _StatusPanel(
              title: 'Storage error',
              subtitle: state.lastError?.toString() ?? 'Unknown error',
            ),
          AppStartupStatus.ready => _ReadyStatePanel(state: state),
        },
      ),
    );
  }
}

class _ReadyStatePanel extends StatelessWidget {
  const _ReadyStatePanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final hub = state.activeWateringHub;
    if (hub == null) {
      return const _StatusPanel(
        title: 'No device',
        subtitle: 'WateringHubState: noDevice',
      );
    }

    return _StatusPanel(
      title: hub.displayName,
      subtitle: 'WateringHubState: ${state.connectionState.label}',
    );
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
  String get label => toJson();
}
