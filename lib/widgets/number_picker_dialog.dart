import 'package:flutter/material.dart';
import '../app_localizations.dart';
import 'number_wheel_picker.dart';

/// Edits a decimal draft; the caller decides how to apply the saved value.
class NumberPickerDialog extends StatefulWidget {
  const NumberPickerDialog({
    super.key,
    required this.title,
    required this.initialValue,
    required this.formatValue,
    this.minWhole = 1,
    this.maxWhole = 99,
  }) : assert(minWhole <= maxWhole),
       assert(initialValue >= minWhole && initialValue < maxWhole + 1);

  final String title;
  final double initialValue;
  final String Function(double) formatValue;
  final int minWhole;
  final int maxWhole;

  @override
  State<NumberPickerDialog> createState() => _NumberPickerDialogState();
}

class _NumberPickerDialogState extends State<NumberPickerDialog> {
  late final int _initial = (widget.initialValue * 100).round().clamp(
    widget.minWhole * 100,
    widget.maxWhole * 100 + 99,
  );
  late int _whole = _initial ~/ 100;
  late int _fraction = _initial % 100;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final separator = Localizations.localeOf(context).languageCode == 'en'
        ? '.'
        : ',';
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.formatValue(_whole + _fraction / 100)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: NumberWheelPicker(
                    key: const ValueKey('number-whole-picker'),
                    label: strings.translate('wholeNumber'),
                    initialIndex: _initial ~/ 100 - widget.minWhole,
                    itemCount: widget.maxWhole - widget.minWhole + 1,
                    formatItem: (index) => '${index + widget.minWhole}',
                    parseInput: (input, _) {
                      final value = int.tryParse(input.trim());
                      if (value == null ||
                          value < widget.minWhole ||
                          value > widget.maxWhole) {
                        return null;
                      }
                      return value - widget.minWhole;
                    },
                    onChanged: (index) =>
                        setState(() => _whole = index + widget.minWhole),
                  ),
                ),
                SizedBox(height: 180, child: Center(child: Text(separator))),
                Expanded(
                  child: NumberWheelPicker(
                    key: const ValueKey('number-fraction-picker'),
                    label: strings.translate('decimalPart'),
                    initialIndex: _initial % 100,
                    itemCount: 100,
                    formatItem: (index) => index.toString().padLeft(2, '0'),
                    parseInput: (input, _) {
                      final value = int.tryParse(input.trim());
                      return value != null && value >= 0 && value < 100
                          ? value
                          : null;
                    },
                    onChanged: (index) => setState(() => _fraction = index),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_whole + _fraction / 100),
          child: Text(strings.save),
        ),
      ],
    );
  }
}
