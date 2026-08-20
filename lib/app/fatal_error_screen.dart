import 'package:flutter/material.dart';

import '../features/service_console/service_console_dependencies.dart';
import 'app_header.dart';
import 'status_panel.dart';

class FatalErrorScreen extends StatelessWidget {
  const FatalErrorScreen({
    required this.error,
    required this.onRetry,
    required this.onRestartOnboarding,
    required this.serviceConsoleDependencies,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onRestartOnboarding;
  final ServiceConsoleDependencies serviceConsoleDependencies;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Автоматичний полив',
        serviceConsoleDependencies: serviceConsoleDependencies,
      ),
      body: SafeArea(
        top: false,
        child: Center(
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
      ),
    );
  }
}
