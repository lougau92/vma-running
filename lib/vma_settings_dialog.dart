import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'widgets/number_wheel_picker.dart';

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
}) => showDialog<VmaTableSettings>(
  context: context,
  builder: (_) => _IntensityRangePicker(initialSettings: initialSettings),
);

class _IntensityRangePicker extends StatefulWidget {
  const _IntensityRangePicker({required this.initialSettings});

  final VmaTableSettings initialSettings;

  @override
  State<_IntensityRangePicker> createState() => _IntensityRangePickerState();
}

class _IntensityRangePickerState extends State<_IntensityRangePicker> {
  late final List<double> _values = {
    ...List<double>.generate(300, (i) => i + 1),
    widget.initialSettings.minPercent,
    widget.initialSettings.maxPercent,
    widget.initialSettings.step,
  }.where((value) => value.isFinite && value > 0).toList()..sort();
  late double _min = widget.initialSettings.minPercent;
  late double _max = widget.initialSettings.maxPercent;
  late double _step = widget.initialSettings.step;
  String? _error;

  int _index(double value) => _values.indexOf(value);

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(strings.adjustIntensity),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NumberWheelPicker(
                    key: const ValueKey('intensity-min-picker'),
                    label: strings.minPercent,
                    initialIndex: _index(_min),
                    itemCount: _values.length,
                    formatItem: (i) => _formatPercent(_values[i]),
                    onChanged: (i) => setState(() {
                      _min = _values[i];
                      _error = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NumberWheelPicker(
                    key: const ValueKey('intensity-max-picker'),
                    label: strings.maxPercent,
                    initialIndex: _index(_max),
                    itemCount: _values.length,
                    formatItem: (i) => _formatPercent(_values[i]),
                    onChanged: (i) => setState(() {
                      _max = _values[i];
                      _error = null;
                    }),
                  ),
                ),
              ],
            ),
            NumberWheelPicker(
              key: const ValueKey('intensity-step-picker'),
              label: strings.stepPercent,
              initialIndex: _index(_step),
              itemCount: _values.length,
              formatItem: (i) => _formatPercent(_values[i]),
              onChanged: (i) => setState(() {
                _step = _values[i];
                _error = null;
              }),
            ),
            if (_error != null)
              Text(
                _error!,
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
              setState(() => _error = strings.minLessThanMax);
            } else if (_step > _max - _min) {
              setState(() => _error = strings.stepTooLarge);
            } else {
              Navigator.of(context).pop(
                VmaTableSettings(
                  minPercent: _min,
                  maxPercent: _max,
                  step: _step,
                ),
              );
            }
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}

String _formatPercent(double value) =>
    '${value == value.roundToDouble() ? value.toInt() : value}%';
