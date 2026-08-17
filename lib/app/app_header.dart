import 'package:flutter/material.dart';

import '../features/service_console/service_console_action.dart';
import '../features/service_console/service_console_dependencies.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    required this.title,
    required this.serviceConsoleDependencies,
    this.actions = const [],
    super.key,
  });

  final String title;
  final ServiceConsoleDependencies serviceConsoleDependencies;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        ServiceConsoleAction(dependencies: serviceConsoleDependencies),
        ...actions,
      ],
    );
  }
}
