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
}) async {
  final strings = AppLocalizations.of(context);
  final selected = await showDialog<RangeValues>(
    context: context,
    builder: (_) => NumberRangePickerDialog(
      title: strings.distanceRange,
      values: presetDistances(),
      initialMin: initialMin,
      initialMax: initialMax,
      formatValue: strings.distanceShort,
    ),
  );
  return selected == null
      ? null
      : DistanceRange(min: selected.start, max: selected.end);
}

Future<TimeRange?> showTimesSettingsDialog(
  BuildContext context, {
  required double initialMinSeconds,
  required double initialMaxSeconds,
}) async {
  final strings = AppLocalizations.of(context);
  final selected = await showDialog<RangeValues>(
    context: context,
    builder: (_) => NumberRangePickerDialog(
      title: strings.timeRange,
      values: presetTimesSeconds(),
      initialMin: initialMinSeconds,
      initialMax: initialMaxSeconds,
      formatValue: (seconds) => formatElapsed(seconds.toInt()),
    ),
  );
  return selected == null
      ? null
      : TimeRange(minSeconds: selected.start, maxSeconds: selected.end);
}
