import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'presets.dart';
import 'time_utils.dart';

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
}) {
  final strings = AppLocalizations.of(context);
  final distances = presetDistances();

  double selectedMin = initialMin;
  double selectedMax = initialMax;
  String? validationError;

  List<DropdownMenuItem<double>> buildItems() => distances
      .map(
        (d) => DropdownMenuItem(
          value: d,
          child: Text(strings.distanceShort(d)),
        ),
      )
      .toList();

  return showDialog<DistanceRange>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: Text(strings.distanceRange),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<double>(
                    value: _closest(distances, selectedMin),
                    isExpanded: true,
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() {
                        selectedMin = value;
                        validationError = null;
                      });
                    },
                    items: buildItems(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<double>(
                    value: _closest(distances, selectedMax),
                    isExpanded: true,
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() {
                        selectedMax = value;
                        validationError = null;
                      });
                    },
                    items: buildItems(),
                  ),
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
              String? error;
              if (selectedMin >= selectedMax) {
                error = strings.minLessThanMax;
              }
              if (error != null) {
                setStateDialog(() => validationError = error);
                return;
              }
              Navigator.of(dialogContext).pop(
                DistanceRange(min: selectedMin, max: selectedMax),
              );
            },
            child: Text(strings.save),
          ),
        ],
      ),
    ),
  );
}

Future<TimeRange?> showTimesSettingsDialog(
  BuildContext context, {
  required double initialMinSeconds,
  required double initialMaxSeconds,
}) {
  final strings = AppLocalizations.of(context);
  final times = presetTimesSeconds();

  double selectedMin = initialMinSeconds;
  double selectedMax = initialMaxSeconds;
  String? validationError;

  List<DropdownMenuItem<double>> buildItems() => times
      .map(
        (t) => DropdownMenuItem(
          value: t,
          child: Text(formatElapsed(t.toInt())),
        ),
      )
      .toList();

  return showDialog<TimeRange>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        title: Text(strings.timeRange),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<double>(
                    value: _closest(times, selectedMin),
                    isExpanded: true,
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() {
                        selectedMin = value;
                        validationError = null;
                      });
                    },
                    items: buildItems(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<double>(
                    value: _closest(times, selectedMax),
                    isExpanded: true,
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() {
                        selectedMax = value;
                        validationError = null;
                      });
                    },
                    items: buildItems(),
                  ),
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
              String? error;
              if (selectedMin >= selectedMax) {
                error = strings.minLessThanMax;
              }
              if (error != null) {
                setStateDialog(() => validationError = error);
                return;
              }
              Navigator.of(dialogContext).pop(
                TimeRange(minSeconds: selectedMin, maxSeconds: selectedMax),
              );
            },
            child: Text(strings.save),
          ),
        ],
      ),
    ),
  );
}

double _closest(List<double> values, double target) {
  double best = values.first;
  double bestDelta = (values.first - target).abs();
  for (final v in values.skip(1)) {
    final delta = (v - target).abs();
    if (delta < bestDelta) {
      best = v;
      bestDelta = delta;
    }
  }
  return best;
}
