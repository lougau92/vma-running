import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../remote_asset_loader.dart';
import '../widgets/training_plan_page.dart';
import '../workouts/workout.dart';
import '../workouts/workout_content.dart';
import '../workouts/workout_session_header.dart';
import '../workouts/workout_view.dart';
import 'preview_data.dart';
import 'preview_support.dart';

@ResponsivePreview(
  group: 'Workout',
  name: 'Plan · groups, sessions and nested blocks',
)
Widget workoutPagePreview() => WorkoutContent(
  conversion: workoutPreviewConversion,
  result: RemoteLoadResult(
    data: workoutPreviewJson,
    origin: RemoteLoadOrigin.cache,
  ),
  userVma: 18,
  onRefresh: () async {},
  waiting: false,
);

@ResponsivePreview(group: 'Workout', name: 'Loading')
Widget workoutLoadingPreview() => TrainingPlanPage(
  userVma: 18,
  loader: PreviewContentLoader(waitForever: true),
);

@ResponsivePreview(group: 'Workout', name: 'Error and retry')
Widget workoutErrorPreview() => TrainingPlanPage(
  userVma: 18,
  loader: PreviewContentLoader(
    terminalError: StateError('Preview network error'),
  ),
);

@ResponsivePreview(group: 'Workout', name: 'Cached plan after refresh failure')
Widget workoutCachedPreview() => TrainingPlanPage(
  userVma: 18,
  loader: PreviewContentLoader(
    results: [
      RemoteLoadResult(
        data: workoutPreviewJson,
        origin: RemoteLoadOrigin.cache,
        refreshing: true,
      ),
    ],
    terminalError: StateError('Preview network error'),
  ),
);

@ResponsivePreview(group: 'Workout parts', name: 'Session header')
Widget workoutHeaderPreview() => Padding(
  padding: const EdgeInsets.all(16),
  child: WorkoutSessionHeader(session: workoutPreviewConversion.workouts.first),
);

@ResponsivePreview(group: 'Workout parts', name: 'Warm-up phase')
Widget workoutWarmupPreview() => _phasePreview(
  0,
  workoutPreviewConversion.workouts.first.versions.first.warmup,
);

@ResponsivePreview(
  group: 'Workout parts',
  name: 'Main phase · warnings and branches',
)
Widget workoutMainPhasePreview() => _phasePreview(
  1,
  workoutPreviewConversion.workouts.first.versions.first.main,
);

@ResponsivePreview(group: 'Workout parts', name: 'Cool-down · not specified')
Widget workoutUnspecifiedPhasePreview() => _phasePreview(
  2,
  workoutPreviewConversion.workouts.first.versions[1].cooldown,
);

Widget _phasePreview(int kind, WorkoutPhase phase) => Builder(
  builder: (context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: WorkoutPhaseCard(
      title: [
        AppLocalizations.of(context).preSession,
        AppLocalizations.of(context).sessionContent,
        AppLocalizations.of(context).cooldown,
      ][kind],
      phase: phase,
      path: '/workouts/0/versions/0/${['warmup', 'main', 'cooldown'][kind]}',
      view: _view(context),
      kind: kind,
    ),
  ),
);

@ResponsivePreview(group: 'Workout parts', name: 'Nested repeat and recovery')
Widget workoutRepeatPreview() =>
    _nodePreview(_firstRepeat, '/workouts/0/versions/0/main/plan/children/0');

@ResponsivePreview(group: 'Workout parts', name: 'Effort, VMA and pace')
Widget workoutEffortPreview() => _nodePreview(
  _firstRepeat.body,
  '/workouts/0/versions/0/main/plan/children/0/body/children/0/body',
);

@ResponsivePreview(group: 'Workout parts', name: 'Recovery')
Widget workoutRecoveryPreview() => _nodePreview(
  _firstRepeat.between!,
  '/workouts/0/versions/0/main/plan/children/0/between',
  between: true,
);

@ResponsivePreview(group: 'Workout parts', name: 'Choice and terrain warning')
Widget workoutChoicePreview() => _nodePreview(
  _mainSequence.children[1],
  '/workouts/0/versions/0/main/plan/children/1',
);

@ResponsivePreview(
  group: 'Workout parts',
  name: 'Optional technique instructions',
)
Widget workoutOptionalPreview() => _nodePreview(
  _mainSequence.children[2],
  '/workouts/0/versions/0/main/plan/children/2',
);

Widget _nodePreview(WorkoutNode node, String path, {bool between = false}) =>
    Builder(
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: WorkoutNodeView(
          node: node,
          path: path,
          view: _view(context),
          between: between,
        ),
      ),
    );

WorkoutNodeViewData _view(BuildContext context) => WorkoutNodeViewData(
  AppLocalizations.of(context),
  18,
  workoutPreviewConversion.issues,
);
WorkoutSequence get _mainSequence =>
    workoutPreviewConversion.workouts.first.versions.first.main.plan!
        as WorkoutSequence;
WorkoutRepeat get _firstRepeat => _mainSequence.children.first as WorkoutRepeat;
