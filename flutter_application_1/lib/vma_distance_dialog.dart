import 'package:flutter/material.dart';

Future<double?> showDistanceDialog(
  BuildContext context, {
  required double initialDistanceMeters,
}) {
  final controller =
      TextEditingController(text: initialDistanceMeters.toStringAsFixed(0));
  String? validationError;

  return showDialog<double>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: const Text('Set target distance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Distance (meters)',
                errorText: validationError,
              ),
              onChanged: (_) {
                if (validationError != null) {
                  setStateDialog(() => validationError = null);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value =
                  double.tryParse(controller.text.replaceAll(',', '.'));
              if (value == null || value <= 0) {
                setStateDialog(
                  () => validationError = 'Enter a distance greater than 0.',
                );
                return;
              }
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
