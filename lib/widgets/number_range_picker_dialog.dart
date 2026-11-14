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
    this.onInputCompleted,
    this.resetValues,
    this.onReset,
  });

  final String title;
  final List<double> values;
  final double initialMin;
  final double initialMax;
  final String Function(double) formatValue;
  final double? Function(String input, double currentValue) parseValueInput;
  final ValueChanged<RangeValues> onChanged;
  final TextInputType? inputKeyboardType;
  final ValueChanged<double>? onInputCompleted;
  final List<double>? resetValues;
  final VoidCallback? onReset;

  @override
  State<NumberRangePickerDialog> createState() =>
      _NumberRangePickerDialogState();
}

class _NumberRangePickerDialogState extends State<NumberRangePickerDialog> {
  late List<double> _values = {
    ...widget.values,
    widget.initialMin,
    widget.initialMax,
  }.toList()..sort();
  late double _min = widget.initialMin;
  late double _max = widget.initialMax;
  late RangeValues _lastApplied = RangeValues(_min, _max);
  int _generation = 0;

  void _update({double? min, double? max}) {
    setState(() {
      _min = min ?? _min;
      _max = max ?? _max;
    });
    if (_min < _max) {
      _lastApplied = RangeValues(_min, _max);
      widget.onChanged(_lastApplied);
    }
  }

  void _completeInput(double value) {
    if (!_values.contains(value)) {
      setState(() => _values = {..._values, value}.toList()..sort());
    }
    widget.onInputCompleted?.call(value);
  }

  void _reset() {
    final presets = widget.resetValues!;
    setState(() {
      _generation++;
      _values = [...presets];
      // Keep the viewed interval, expanding custom endpoints to neighboring
      // presets so clearing custom rows cannot leave a range without rows.
      _min = presets.lastWhere(
        (value) => value <= _lastApplied.start,
        orElse: () => presets.first,
      );
      _max = presets.firstWhere(
        (value) => value >= _lastApplied.end,
        orElse: () => presets.last,
      );
      if (_min >= _max) {
        final index = presets.indexOf(_min).clamp(0, presets.length - 2);
        _min = presets[index];
        _max = presets[index + 1];
      }
      _lastApplied = RangeValues(_min, _max);
    });
    widget.onChanged(_lastApplied);
    widget.onReset?.call();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final generation = _generation;
    final canReset =
        widget.onReset != null &&
        widget.resetValues != null &&
        _values.any((value) => !widget.resetValues!.contains(value));
    Widget picker(bool minimum) => NumberValueWheelPicker(
      key: ValueKey('range-${minimum ? 'min' : 'max'}-picker'),
      label: strings.translate(minimum ? 'minimum' : 'maximum'),
      initialValue: minimum ? _min : _max,
      values: _values,
      formatValue: widget.formatValue,
      parseInput: widget.parseValueInput,
      minValue: 0.001,
      inputKeyboardType: widget.inputKeyboardType,
      onChanged: (value) => minimum ? _update(min: value) : _update(max: value),
      onInputCompleted: (value) {
        // A reset also discards an unfinished edit from the previous wheels.
        if (generation == _generation) _completeInput(value);
      },
    );
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(
              key: ValueKey(_generation),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: picker(true)),
                  const SizedBox(width: 12),
                  Expanded(child: picker(false)),
                ],
              ),
            ),
            if (_min >= _max)
              Text(
                strings.minLessThanMax,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (canReset)
              TextButton.icon(
                key: const ValueKey('reset-custom-rows'),
                onPressed: _reset,
                icon: const Icon(Icons.restart_alt),
                label: Text(strings['resetCustomRows']),
              ),
          ],
        ),
      ),
    );
  }
}
