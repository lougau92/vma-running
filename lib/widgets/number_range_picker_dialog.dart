import 'package:flutter/material.dart';
import '../app_localizations.dart';
import 'number_wheel_picker.dart';

/// Selects ordered bounds from numeric presets without discarding custom bounds.
class NumberRangePickerDialog extends StatefulWidget {
  const NumberRangePickerDialog({
    super.key,
    required this.title,
    required this.values,
    required this.initialMin,
    required this.initialMax,
    required this.formatValue,
  });

  final String title;
  final List<double> values;
  final double initialMin;
  final double initialMax;
  final String Function(double) formatValue;

  @override
  State<NumberRangePickerDialog> createState() =>
      _NumberRangePickerDialogState();
}

class _NumberRangePickerDialogState extends State<NumberRangePickerDialog> {
  late final _values = {
    ...widget.values,
    widget.initialMin,
    widget.initialMax,
  }.toList()..sort();
  late double _min = widget.initialMin;
  late double _max = widget.initialMax;
  bool _invalid = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AlertDialog(
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
                  child: NumberWheelPicker(
                    key: const ValueKey('range-min-picker'),
                    label: strings.translate('minimum'),
                    initialIndex: _values.indexOf(widget.initialMin),
                    itemCount: _values.length,
                    formatItem: (index) => widget.formatValue(_values[index]),
                    onChanged: (index) => setState(() {
                      _min = _values[index];
                      _invalid = false;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberWheelPicker(
                    key: const ValueKey('range-max-picker'),
                    label: strings.translate('maximum'),
                    initialIndex: _values.indexOf(widget.initialMax),
                    itemCount: _values.length,
                    formatItem: (index) => widget.formatValue(_values[index]),
                    onChanged: (index) => setState(() {
                      _max = _values[index];
                      _invalid = false;
                    }),
                  ),
                ),
              ],
            ),
            if (_invalid)
              Text(
                strings.minLessThanMax,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
          onPressed: () {
            if (_min >= _max) {
              setState(() => _invalid = true);
              return;
            }
            Navigator.of(context).pop(RangeValues(_min, _max));
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}
