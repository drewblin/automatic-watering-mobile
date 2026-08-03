import 'package:flutter/material.dart';

class HomeSection extends StatelessWidget {
  const HomeSection({
    required this.title,
    required this.emptyText,
    required this.children,
    super.key,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Text(emptyText)
          else
            ...children.expand((child) => [child, const SizedBox(height: 8)]),
        ],
      ),
    );
  }
}
