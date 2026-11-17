import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../presets.dart';
import '../running.dart';
import '../widgets/distance_dialog.dart';
import '../widgets/intensity_pace_control.dart';
import '../widgets/intensity_tab.dart';
import '../widgets/pace_table.dart';
import '../widgets/pace_table_settings_dialog.dart';
import '../widgets/running_calculator_tab.dart';
import '../widgets/times_tab.dart';
import '../widgets/times_table.dart';
import 'preview_support.dart';

@ResponsivePreview(group: 'Intensity', name: 'Intensity table')
Widget intensityTabPreview() => const IntensityTab(vma: 18);

@ResponsivePreview(
  group: 'Intensity',
  name: 'Pace table with editable settings',
)
Widget paceTablePreview() => Builder(
  builder: (context) {
    const minPercent = 60.0;
    const maxPercent = 120.0;
    const step = 5.0;
    const distanceMeters = 400.0;
    return PaceTable(
      entries: PaceTable.buildEntries(
        18,
        minPercent: minPercent,
        maxPercent: maxPercent,
        step: step,
        distanceMeters: distanceMeters,
      ),
      distanceMeters: distanceMeters,
      onEditPercentages: () => showTableSettingsDialog(
        context,
        initialSettings: const TableSettings(
          minPercent: minPercent,
          maxPercent: maxPercent,
          step: step,
        ),
      ),
      onEditDistance: () =>
          showDistanceDialog(context, initialDistanceMeters: distanceMeters),
    );
  },
);

@ResponsivePreview(group: 'Intensity', name: 'Intensity and pace control')
Widget intensityControlPreview() => const _IntensityControlPreview();

class _IntensityControlPreview extends StatefulWidget {
  const _IntensityControlPreview();
  @override
  State<_IntensityControlPreview> createState() =>
      _IntensityControlPreviewState();
}

class _IntensityControlPreviewState extends State<_IntensityControlPreview> {
  double _percent = 90;
  @override
  Widget build(BuildContext context) => IntensityPaceControl(
    percent: _percent,
    speed: RunningSpeed.fromVma(18, _percent),
    onChanged: (value) => setState(() => _percent = value),
  );
}

@ResponsivePreview(group: 'Times', name: 'Times table and intensity control')
Widget timesTabPreview() => const _TimesTabPreview();

class _TimesTabPreview extends StatefulWidget {
  const _TimesTabPreview();
  @override
  State<_TimesTabPreview> createState() => _TimesTabPreviewState();
}

class _TimesTabPreviewState extends State<_TimesTabPreview> {
  AppSettings _settings = const AppSettings();
  @override
  Widget build(BuildContext context) => TimesTab(
    vma: 18,
    settings: _settings,
    onSettingsChanged: (value) => setState(() => _settings = value),
  );
}

@ResponsivePreview(group: 'Times', name: 'Distance and time rows')
Widget timesRowsPreview() => Builder(
  builder: (context) => SizedBox.expand(
    child: TimesTable(
      speed: RunningSpeed.fromVma(18, 100)!,
      minDistanceMeters: 100,
      maxDistanceMeters: 5000,
      minTimeSeconds: presetTimesSeconds().first,
      maxTimeSeconds: presetTimesSeconds().last,
      customDistances: const [1350, 2750],
      customTimes: const [333, 777],
      onEditDistances: () {},
      onEditTimes: () {},
    ),
  ),
);

@ResponsivePreview(group: 'Calculator', name: 'Calculation with saved VMA')
Widget calculatorPreview() =>
    RunningCalculatorTab(savedVma: 18, onNavigatePage: (_) {});

@ResponsivePreview(group: 'Calculator', name: 'VMA not set')
Widget calculatorMissingVmaPreview() =>
    RunningCalculatorTab(savedVma: null, onNavigatePage: (_) {});
