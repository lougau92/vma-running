import 'package:flutter/material.dart';

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
        title: const Text('Adjust intensity range'),
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
                  label: 'Min %',
                ),
                _NumberField(
                  controller: maxController,
                  label: 'Max %',
                ),
                _NumberField(
                  controller: stepController,
                  label: 'Step %',
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
              final minValue =
                  double.tryParse(minController.text.replaceAll(',', '.'));
              final maxValue =
                  double.tryParse(maxController.text.replaceAll(',', '.'));
              final stepValue =
                  double.tryParse(stepController.text.replaceAll(',', '.'));

              String? error;
              if (minValue == null || maxValue == null || stepValue == null) {
                error = 'Use numbers only.';
              } else if (minValue <= 0 || maxValue <= 0 || stepValue <= 0) {
                error = 'Values must be greater than 0.';
              } else if (minValue >= maxValue) {
                error = 'Min must be less than Max.';
              } else if (stepValue > (maxValue - minValue)) {
                error = 'Step is too large for the range.';
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
