import 'package:flutter/widgets.dart';

class ServiceConsoleTab {
  const ServiceConsoleTab({
    required this.label,
    required this.builder,
  });

  final String label;
  final WidgetBuilder builder;
}
