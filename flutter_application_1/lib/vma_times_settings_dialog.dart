import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'distance_input.dart';

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
  final strings = AppLocalizations.of(context);
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
        title: Text(strings.distanceRange),
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
                  label: strings.minMeters,
                  onTap: () => activeController = minController,
                ),
                _NumberField(
                  controller: maxController,
                  label: strings.maxMeters,
                  onTap: () => activeController = maxController,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text(strings.halfMarathon),
                  onPressed: () {
                    (activeController ?? maxController).text =
                        kHalfMarathonMeters.toStringAsFixed(0);
                    setStateDialog(() => validationError = null);
                  },
                ),
                ActionChip(
                  label: Text(strings.marathon),
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
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () {
              final minValue = parseDistanceInput(minController.text);
              final maxValue = parseDistanceInput(maxController.text);

              String? error;
              if (minValue == null || maxValue == null) {
                error = strings.useNumbersOnly;
              } else if (minValue <= 0 || maxValue <= 0) {
                error = strings.valuesGreaterThanZero;
              } else if (minValue >= maxValue) {
                error = strings.minLessThanMax;
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
            child: Text(strings.save),
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
