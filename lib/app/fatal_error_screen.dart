import 'package:flutter/material.dart';

import 'status_panel.dart';

class FatalErrorScreen extends StatelessWidget {
  const FatalErrorScreen({
    required this.error,
    required this.onRetry,
    required this.onRestartOnboarding,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onRestartOnboarding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Автоматичний полив')),
      body: Center(
        child: StatusPanel(
          title: 'Помилка запуску',
          subtitle: error.toString(),
          action: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторити'),
              ),
              OutlinedButton.icon(
                onPressed: onRestartOnboarding,
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('Повторити onboarding'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
