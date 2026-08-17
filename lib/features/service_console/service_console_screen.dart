import 'package:flutter/material.dart';

import 'service_console_dependencies.dart';
import 'service_console_tabs.dart';

class ServiceConsoleScreen extends StatelessWidget {
  const ServiceConsoleScreen({
    required this.dependencies,
    super.key,
  });

  final ServiceConsoleDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final tabs = buildServiceConsoleTabs(dependencies);

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Сервісна консоль'),
          bottom: TabBar(
            tabs: [
              for (final tab in tabs) Tab(text: tab.label),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in tabs) Builder(builder: tab.builder),
          ],
        ),
      ),
    );
  }
}
