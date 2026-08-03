import 'package:flutter/material.dart';

Future<int?> showOpenValveDialog({
  required BuildContext context,
  required String valveName,
  required int defaultSeconds,
  required int maxSeconds,
}) async {
  final controller = TextEditingController(text: defaultSeconds.toString());
  String? error;
  return showDialog<int>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Відкрити клапан?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(valveName),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Тривалість, с',
                    helperText: 'Максимум $maxSeconds с',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Скасувати'),
              ),
              FilledButton(
                onPressed: () {
                  final seconds = int.tryParse(controller.text.trim());
                  if (seconds == null || seconds <= 0) {
                    setState(() {
                      error = 'Введіть додатну кількість секунд.';
                    });
                    return;
                  }
                  if (seconds > maxSeconds) {
                    setState(() {
                      error =
                          'Час відкриття не може перевищувати $maxSeconds с.';
                    });
                    return;
                  }
                  Navigator.of(context).pop(seconds);
                },
                child: const Text('Відкрити'),
              ),
            ],
          );
        },
      );
    },
  );
}
