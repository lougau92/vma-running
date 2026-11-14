import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'presets.dart';
import 'running/running.dart';
import 'widgets/number_wheel_picker.dart';

Future<double?> showDistanceDialog(
  BuildContext context, {
  required double initialDistanceMeters,
  ValueChanged<double>? onChanged,
}) async {
  final strings = AppLocalizations.of(context);
  var selected = initialDistanceMeters;
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      scrollable: true,
      title: Text(strings.setTargetDistance),
      content: SizedBox(
        width: 280,
        child: NumberValueWheelPicker(
          key: const ValueKey('target-distance-picker'),
          label: strings.distanceMetersLabel,
          initialValue: initialDistanceMeters,
          values: presetDistances(),
          formatValue: (meters) =>
              '${meters == meters.roundToDouble() ? meters.toInt() : meters} m',
          parseInput: (input, _) => parseDistanceInput(input),
          minValue: 0.001,
          onChanged: (value) {
            selected = value;
            onChanged?.call(value);
          },
        ),
      ),
    ),
  );
  return selected;
}
