import 'package:flutter/material.dart';
import 'distance_extensions.dart';

class VmaTimesSettings {
  const VmaTimesSettings({
    required this.minDistance,
    required this.maxDistance,
  });

  final double minDistance;
  final double maxDistance;
}

Future<VmaTimesSettings?> showTimesSettingsDialog(
  BuildContext context, {
  required VmaTimesSettings initialSettings,
}) {
  final minController =
      TextEditingController(text: initialSettings.minDistance.toStringAsFixed(0));
  final maxController =
      TextEditingController(text: initialSettings.maxDistance.toStringAsFixed(0));
  String? validationError;
  TextEditingController? activeController;

  return showDialog<VmaTimesSettings>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: const Text('Distance range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _NumberField(
                  controller: minController,
                  label: 'Min (m)',
                  onTap: () => activeController = minController,
                ),
                _NumberField(
                  controller: maxController,
                  label: 'Max (m)',
                  onTap: () => activeController = maxController,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Half marathon'),
                  onPressed: () {
                    (activeController ?? maxController).text =
                        kHalfMarathonMeters.toStringAsFixed(0);
                    setStateDialog(() => validationError = null);
                  },
                ),
                ActionChip(
                  label: const Text('Marathon'),
                  onPressed: () {
                    (activeController ?? maxController).text =
                        kMarathonMeters.toStringAsFixed(0);
                    setStateDialog(() => validationError = null);
                  },
                ),
              ],
            ),
            if (validationError != null) ...[
              const SizedBox(height: 12),
              Text(
                validationError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final minValue = parseDistanceInput(minController.text);
              final maxValue = parseDistanceInput(maxController.text);

              String? error;
              if (minValue == null || maxValue == null) {
                error = 'Use numbers only.';
              } else if (minValue <= 0 || maxValue <= 0) {
                error = 'Values must be greater than 0.';
              } else if (minValue >= maxValue) {
                error = 'Min must be less than Max.';
              }

              if (error != null) {
                setStateDialog(() => validationError = error);
                return;
              }

              Navigator.of(dialogContext).pop(
                VmaTimesSettings(
                  minDistance: minValue!,
                  maxDistance: maxValue!,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
        ),
        onTap: onTap,
      ),
    );
  }
}
