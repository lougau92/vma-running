import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'presets.dart';
import 'running/running.dart';
import 'widgets/number_range_picker_dialog.dart';

class DistanceRange {
  const DistanceRange({required this.min, required this.max});
  final double min;
  final double max;
}

class TimeRange {
  const TimeRange({required this.minSeconds, required this.maxSeconds});
  final double minSeconds;
  final double maxSeconds;
}

Future<DistanceRange?> showDistancesSettingsDialog(
  BuildContext context, {
  required double initialMin,
  required double initialMax,
  ValueChanged<DistanceRange>? onChanged,
}) async {
  final strings = AppLocalizations.of(context);
  var selected = RangeValues(initialMin, initialMax);
  await showDialog<void>(
    context: context,
    builder: (_) => NumberRangePickerDialog(
      title: strings.distanceRange,
      values: presetDistances(),
      initialMin: initialMin,
      initialMax: initialMax,
      formatValue: strings.distanceShort,
      onChanged: (range) {
        selected = range;
        onChanged?.call(DistanceRange(min: range.start, max: range.end));
      },
      parseValueInput: (input, currentValue) {
        final bareNumber = double.tryParse(input.trim().replaceAll(',', '.'));
        if (bareNumber != null && currentValue >= 1000) {
          final meters = bareNumber * 1000;
          return meters.isFinite ? meters : null;
        }
        return parseDistanceInput(input);
      },
    ),
  );
  return DistanceRange(min: selected.start, max: selected.end);
}

Future<TimeRange?> showTimesSettingsDialog(
  BuildContext context, {
  required double initialMinSeconds,
  required double initialMaxSeconds,
  ValueChanged<TimeRange>? onChanged,
}) async {
  final strings = AppLocalizations.of(context);
  var selected = RangeValues(initialMinSeconds, initialMaxSeconds);
  await showDialog<void>(
    context: context,
    builder: (_) => NumberRangePickerDialog(
      title: strings.timeRange,
      values: presetTimesSeconds(),
      initialMin: initialMinSeconds,
      initialMax: initialMaxSeconds,
      formatValue: (seconds) => formatElapsed(seconds.toInt()),
      parseValueInput: (input, _) => parseRunningDuration(input),
      onChanged: (range) {
        selected = range;
        onChanged?.call(
          TimeRange(minSeconds: range.start, maxSeconds: range.end),
        );
      },
      inputKeyboardType: TextInputType.text,
    ),
  );
  return TimeRange(minSeconds: selected.start, maxSeconds: selected.end);
}
