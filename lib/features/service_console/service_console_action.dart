import 'package:flutter/material.dart';

import 'service_console_dependencies.dart';
import 'service_console_screen.dart';

class ServiceConsoleAction extends StatelessWidget {
  const ServiceConsoleAction({
    required this.dependencies,
    super.key,
  });

  final ServiceConsoleDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Сервісна консоль',
      icon: const Icon(Icons.build),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ServiceConsoleScreen(dependencies: dependencies),
        ),
      ),
    );
  }
}
