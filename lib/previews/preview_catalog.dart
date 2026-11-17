import 'package:flutter/widgets.dart';

import 'app_previews.dart';
import 'celebration_previews.dart';
import 'control_previews.dart';
import 'running_previews.dart';
import 'settings_previews.dart';
import 'workout_previews.dart';

/// One source for catalogue smoke tests and a quick list of useful UI states.
class PreviewScenario {
  const PreviewScenario(
    this.name,
    this.build, {
    this.continuousAnimation = false,
  });
  final String name;
  final Widget Function() build;
  final bool continuousAnimation;
}

final previewScenarios = <PreviewScenario>[
  PreviewScenario('Workout plan', workoutPagePreview),
  PreviewScenario(
    'Workout loading',
    workoutLoadingPreview,
    continuousAnimation: true,
  ),
  PreviewScenario('Workout error', workoutErrorPreview),
  PreviewScenario('Workout cached content', workoutCachedPreview),
  PreviewScenario('Workout header', workoutHeaderPreview),
  PreviewScenario('Workout warm-up', workoutWarmupPreview),
  PreviewScenario('Workout main phase', workoutMainPhasePreview),
  PreviewScenario('Workout unspecified phase', workoutUnspecifiedPhasePreview),
  PreviewScenario('Workout repeat', workoutRepeatPreview),
  PreviewScenario('Workout effort', workoutEffortPreview),
  PreviewScenario('Workout recovery', workoutRecoveryPreview),
  PreviewScenario('Workout choice', workoutChoicePreview),
  PreviewScenario('Workout optional step', workoutOptionalPreview),
  PreviewScenario('Intensity tab', intensityTabPreview),
  PreviewScenario('Pace table', paceTablePreview),
  PreviewScenario('Intensity control', intensityControlPreview),
  PreviewScenario('Times tab', timesTabPreview),
  PreviewScenario('Times rows', timesRowsPreview),
  PreviewScenario('Calculator', calculatorPreview),
  PreviewScenario('Calculator without VMA', calculatorMissingVmaPreview),
  PreviewScenario('Settings', settingsPreview),
  PreviewScenario('Settings without VMA', settingsMissingVmaPreview),
  PreviewScenario('App workspace', appWorkspacePreview),
  PreviewScenario('App workspace without VMA', appWorkspaceMissingVmaPreview),
  PreviewScenario(
    'App loading',
    appWorkspaceLoadingPreview,
    continuousAnimation: true,
  ),
  PreviewScenario('VMA picker', vmaPickerPreview),
  PreviewScenario('Editable wheel', editableWheelPreview),
  PreviewScenario('Distance picker', distanceDialogPreview),
  PreviewScenario('Intensity range dialog', intensityRangeDialogPreview),
  PreviewScenario('Distance range dialog', distanceRangeDialogPreview),
  PreviewScenario('Time range dialog', timeRangeDialogPreview),
  PreviewScenario('Range picker', rangePickerPreview),
  PreviewScenario(
    'VMA celebration',
    vmaCelebrationPreview,
    continuousAnimation: true,
  ),
];
