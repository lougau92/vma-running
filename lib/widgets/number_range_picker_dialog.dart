import 'package:flutter/material.dart';
import '../app_localizations.dart';
import 'number_wheel_picker.dart';

/// Selects ordered bounds and applies each valid range without a Save action.
class NumberRangePickerDialog extends StatefulWidget {
  const NumberRangePickerDialog({
    super.key,
    required this.title,
    required this.values,
    required this.initialMin,
    required this.initialMax,
    required this.formatValue,
    required this.parseValueInput,
    required this.onChanged,
    this.inputKeyboardType,
  });

  final String title;
  final List<double> values;
  final double initialMin;
  final double initialMax;
  final String Function(double) formatValue;
  final double? Function(String input, double currentValue) parseValueInput;
  final ValueChanged<RangeValues> onChanged;
  final TextInputType? inputKeyboardType;

  @override
  State<NumberRangePickerDialog> createState() =>
      _NumberRangePickerDialogState();
}

class _NumberRangePickerDialogState extends State<NumberRangePickerDialog> {
  late double _min = widget.initialMin;
  late double _max = widget.initialMax;

  void _update({double? min, double? max}) {
    setState(() {
      _min = min ?? _min;
      _max = max ?? _max;
    });
    if (_min < _max) widget.onChanged(RangeValues(_min, _max));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NumberValueWheelPicker(
                    key: const ValueKey('range-min-picker'),
                    label: strings.translate('minimum'),
                    initialValue: widget.initialMin,
                    values: widget.values,
                    formatValue: widget.formatValue,
                    parseInput: widget.parseValueInput,
                    minValue: widget.values.first,
                    maxValue: widget.values.last,
                    inputKeyboardType: widget.inputKeyboardType,
                    onChanged: (value) => _update(min: value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberValueWheelPicker(
                    key: const ValueKey('range-max-picker'),
                    label: strings.translate('maximum'),
                    initialValue: widget.initialMax,
                    values: widget.values,
                    formatValue: widget.formatValue,
                    parseInput: widget.parseValueInput,
                    minValue: widget.values.first,
                    maxValue: widget.values.last,
                    inputKeyboardType: widget.inputKeyboardType,
                    onChanged: (value) => _update(max: value),
                  ),
                ),
              ],
            ),
            if (_min >= _max)
              Text(
                strings.minLessThanMax,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
