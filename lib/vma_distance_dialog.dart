import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'distance_extensions.dart';

Future<double?> showDistanceDialog(
  BuildContext context, {
  required double initialDistanceMeters,
}) {
  final strings = AppLocalizations.of(context);
  final controller = TextEditingController(
    text: initialDistanceMeters.toStringAsFixed(0),
  );
  String? validationError;

  return showDialog<double>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: Text(strings.setTargetDistance),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: strings.distanceMetersLabel,
                errorText: validationError,
              ),
              onChanged: (_) {
                if (validationError != null) {
                  setStateDialog(() => validationError = null);
                }
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text(strings.halfMarathon),
                  onPressed: () {
                    controller.text = kHalfMarathonMeters.toStringAsFixed(0);
                    setStateDialog(() => validationError = null);
                  },
                ),
                ActionChip(
                  label: Text(strings.marathon),
                  onPressed: () {
                    controller.text = kMarathonMeters.toStringAsFixed(0);
                    setStateDialog(() => validationError = null);
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () {
              final value = parseDistanceInput(controller.text);
              if (value == null || value <= 0) {
                setStateDialog(
                  () => validationError = strings.distanceGreaterThanZero,
                );
                return;
              }
              Navigator.of(dialogContext).pop(value);
            },
            child: Text(strings.save),
          ),
        ],
      ),
    ),
  );
}
