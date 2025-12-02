import 'package:flutter/material.dart';
import 'app_localizations.dart';

class VmaTableSettings {
  const VmaTableSettings({
    required this.minPercent,
    required this.maxPercent,
    required this.step,
  });

  final double minPercent;
  final double maxPercent;
  final double step;
}

Future<VmaTableSettings?> showVmaSettingsDialog(
  BuildContext context, {
  required VmaTableSettings initialSettings,
}) {
  final strings = AppLocalizations.of(context);
  final minController =
      TextEditingController(text: initialSettings.minPercent.toStringAsFixed(0));
  final maxController =
      TextEditingController(text: initialSettings.maxPercent.toStringAsFixed(0));
  final stepController =
      TextEditingController(text: initialSettings.step.toStringAsFixed(0));
  String? validationError;

  return showDialog<VmaTableSettings>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: Text(strings.adjustIntensity),
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
                  label: strings.minPercent,
                ),
                _NumberField(
                  controller: maxController,
                  label: strings.maxPercent,
                ),
                _NumberField(
                  controller: stepController,
                  label: strings.stepPercent,
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
                final minValue =
                    double.tryParse(minController.text.replaceAll(',', '.'));
              final maxValue =
                  double.tryParse(maxController.text.replaceAll(',', '.'));
              final stepValue =
                  double.tryParse(stepController.text.replaceAll(',', '.'));

                String? error;
                if (minValue == null || maxValue == null || stepValue == null) {
                  error = strings.useNumbersOnly;
                } else if (minValue <= 0 || maxValue <= 0 || stepValue <= 0) {
                  error = strings.valuesGreaterThanZero;
                } else if (minValue >= maxValue) {
                  error = strings.minLessThanMax;
                } else if (stepValue > (maxValue - minValue)) {
                  error = strings.stepTooLarge;
                }

                if (error != null) {
                  setStateDialog(() => validationError = error);
                  return;
                }

                Navigator.of(dialogContext).pop(
                  VmaTableSettings(
                    minPercent: minValue!,
                    maxPercent: maxValue!,
                    step: stepValue!,
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
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
        ),
      ),
    );
  }
}
