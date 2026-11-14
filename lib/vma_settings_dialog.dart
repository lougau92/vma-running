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
  ValueChanged<VmaTableSettings>? onChanged,
}) async {
  var selected = initialSettings;
  await showDialog<void>(
    context: context,
    builder: (_) => _IntensityRangePicker(
      initialSettings: initialSettings,
      onChanged: (value) {
        selected = value;
        onChanged?.call(value);
      },
    ),
  );
  return selected;
}

class _IntensityRangePicker extends StatefulWidget {
  const _IntensityRangePicker({
    required this.initialSettings,
    required this.onChanged,
  });

  final VmaTableSettings initialSettings;
  final ValueChanged<VmaTableSettings> onChanged;

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

  void _applySettings() {
    final strings = AppLocalizations.of(context);
    if (_min >= _max) {
      _error = strings.minLessThanMax;
    } else if (_step > _max - _min) {
      _error = strings.stepTooLarge;
    } else {
      _error = null;
      widget.onChanged(
        VmaTableSettings(minPercent: _min, maxPercent: _max, step: _step),
      );
    }
  }

  Widget _picker(
    String id,
    String label,
    double value,
    double width,
    ValueChanged<double> update,
  ) => SizedBox(
    width: width,
    child: NumberValueWheelPicker(
      key: ValueKey('intensity-$id-picker'),
      label: label,
      initialValue: value,
      values: _values,
      formatValue: _formatPercent,
      minValue: _values.first,
      maxValue: _values.last,
      parseInput: (input, _) => double.tryParse(
        input.trim().replaceAll('%', '').replaceAll(',', '.'),
      ),
      onChanged: (value) => setState(() {
        update(value);
        _applySettings();
      }),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(strings.adjustIntensity),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final minWidth =
                      112 * MediaQuery.textScalerOf(context).scale(14) / 14;
                  final columns =
                      ((constraints.maxWidth + spacing) / (minWidth + spacing))
                          .floor()
                          .clamp(1, 3);
                  final width =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                      columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 16,
                    children: [
                      _picker(
                        'min',
                        strings.minPercent,
                        _min,
                        width,
                        (value) => _min = value,
                      ),
                      _picker(
                        'max',
                        strings.maxPercent,
                        _max,
                        width,
                        (value) => _max = value,
                      ),
                      _picker(
                        'step',
                        strings.stepPercent,
                        _step,
                        width,
                        (value) => _step = value,
                      ),
                    ],
                  );
                },
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatPercent(double value) =>
    '${value == value.roundToDouble() ? value.toInt() : value}%';
