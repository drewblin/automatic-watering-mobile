import 'package:flutter/material.dart';

import 'status_panel.dart';

class FatalErrorScreen extends StatelessWidget {
  const FatalErrorScreen({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Автоматичний полив')),
      body: Center(
        child: StatusPanel(
          title: 'Помилка запуску',
          subtitle: error.toString(),
          action: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторити'),
          ),
        ),
      ),
    );
  }
}
