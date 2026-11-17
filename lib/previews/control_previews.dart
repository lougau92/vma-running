import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../presets.dart';
import '../running.dart';
import '../widgets/distance_dialog.dart';
import '../widgets/number_picker_dialog.dart';
import '../widgets/number_range_picker_dialog.dart';
import '../widgets/number_wheel_picker.dart';
import '../widgets/pace_table_settings_dialog.dart';
import '../widgets/times_settings_dialog.dart';
import 'preview_support.dart';

@ResponsivePreview(group: 'Pickers', name: 'VMA editor')
Widget vmaPickerPreview() => DialogPreviewLauncher(
  onOpen: (context) {
    final strings = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (context) => NumberPickerDialog(
        title: strings.enterVmaTitle,
        initialValue: 17.15,
        formatValue: strings.yourVma,
        onChanged: (_) {},
      ),
    );
  },
);

@ResponsivePreview(group: 'Pickers', name: 'Editable number wheel')
Widget editableWheelPreview() => Builder(
  builder: (context) => AlertDialog(
    title: Text(AppLocalizations.of(context).setTargetDistance),
    content: NumberValueWheelPicker(
      label: AppLocalizations.of(context).distanceMetersLabel,
      initialValue: 400,
      values: presetDistances(),
      formatValue: (value) => '${value.toStringAsFixed(0)} m',
      parseInput: (input, _) => parseDistanceInput(input),
      onChanged: (_) {},
      minValue: 1,
    ),
  ),
);

@ResponsivePreview(group: 'Pickers', name: 'Target distance dialog')
Widget distanceDialogPreview() => DialogPreviewLauncher(
  onOpen: (context) async {
    await showDistanceDialog(context, initialDistanceMeters: 400);
  },
);

@ResponsivePreview(group: 'Pickers', name: 'Intensity range dialog')
Widget intensityRangeDialogPreview() => DialogPreviewLauncher(
  onOpen: (context) async {
    await showTableSettingsDialog(
      context,
      initialSettings: const TableSettings(
        minPercent: 60,
        maxPercent: 120,
        step: 5,
      ),
    );
  },
);

@ResponsivePreview(group: 'Pickers', name: 'Distance range dialog')
Widget distanceRangeDialogPreview() => DialogPreviewLauncher(
  onOpen: (context) async {
    await showDistancesSettingsDialog(
      context,
      initialMin: 100,
      initialMax: 5000,
      customValues: const [1350, 2750],
      onCustomValueAdded: (_) {},
      onResetCustomValues: () {},
    );
  },
);

@ResponsivePreview(group: 'Pickers', name: 'Time range dialog')
Widget timeRangeDialogPreview() => DialogPreviewLauncher(
  onOpen: (context) async {
    await showTimesSettingsDialog(
      context,
      initialMinSeconds: presetTimesSeconds().first,
      initialMaxSeconds: presetTimesSeconds().last,
      customValues: const [333, 777],
      onCustomValueAdded: (_) {},
      onResetCustomValues: () {},
    );
  },
);

@ResponsivePreview(group: 'Pickers', name: 'Number range picker')
Widget rangePickerPreview() => Builder(
  builder: (context) => NumberRangePickerDialog(
    title: AppLocalizations.of(context).distanceRange,
    values: presetDistances(),
    initialMin: 100,
    initialMax: 5000,
    formatValue: (value) => AppLocalizations.of(context).distanceShort(value),
    parseValueInput: (input, _) => parseDistanceInput(input),
    onChanged: (_) {},
  ),
);
