import '../app_localizations.dart';
import '../watch/watch_workout.dart';
import '../workouts/workout.dart';

export '../watch/watch_workout.dart' show ExportInput;

class GarminExport {
  GarminExport(this.payload, this.inputs, this.warnings, this.problems);
  final Map<String, dynamic> payload;
  final List<ExportInput> inputs;
  final List<String> warnings, problems;
  bool get ready => inputs.every((input) => input.resolved) && problems.isEmpty;
}

/// Resolution values are export-only. The source plan is never modified.
GarminExport buildGarminExport(
  WorkoutSession session,
  WorkoutVersion version,
  double vma,
  AppLocalizations s, {
  Map<String, double> values = const {},
  bool defaultChoices = false,
  List<WorkoutNote> notes = const [],
}) {
  final workout = resolveWatchWorkout(
    session,
    version,
    vma,
    s,
    values: values,
    defaultChoices: defaultChoices,
    notes: notes,
  );
  final warnings = [...workout.warnings];
  final problems = [...workout.problems];
  final steps = <Map<String, dynamic>>[];
  String clip(String text, int max) {
    final chars = text.runes.toList();
    if (chars.length <= max) return text;
    warnings.add(s['garmin_shortened']);
    return '${String.fromCharCodes(chars.take(max - 1))}…';
  }

  void append(List<ResolvedWatchNode> nodes) {
    for (final node in nodes) {
      if (steps.length > 200) return;
      switch (node) {
        case ResolvedWatchRepeat():
          if (node.body.isEmpty && node.between.isEmpty) continue;
          for (var i = 0; i < node.count && steps.length <= 200; i++) {
            append(node.body);
            if (i + 1 < node.count) append(node.between);
          }
        case ResolvedWatchStep():
          final type = node.role;
          final amount = node.amount;
          final slow = node.slowSpeed;
          final fast = node.fastSpeed;
          final description = node.notes;
          final (endKey, endId) = switch (node.end) {
            'time' => ('time', 2),
            'distance' => ('distance', 3),
            _ => ('lap.button', 1),
          };
          steps.add({
            'type': 'ExecutableStepDTO',
            'stepOrder': steps.length + 1,
            'stepType': {
              'stepTypeId': {
                'warmup': 1,
                'cooldown': 2,
                'interval': 3,
                'recovery': 4,
                'rest': 5,
              }[type],
              'stepTypeKey': type,
            },
            'endCondition': {
              'conditionTypeId': endId,
              'conditionTypeKey': endKey,
            },
            if (amount != null) 'endConditionValue': amount,
            'targetType': {
              'workoutTargetTypeId': fast == null ? 1 : 6,
              'workoutTargetTypeKey': fast == null ? 'no.target' : 'pace.zone',
            },
            if (fast != null) 'targetValueOne': fast,
            if (slow != null) 'targetValueTwo': slow,
            if (description.isNotEmpty)
              'description': clip(description.join('\n'), 1024),
          });
      }
    }
  }

  append(workout.nodes);
  if (steps.isEmpty) problems.add(s['garmin_empty']);
  if (steps.length > 200) problems.add(s['garmin_too_many']);
  final sport = {'sportTypeId': 1, 'sportTypeKey': 'running'};
  final description = workout.description;
  final payload = <String, dynamic>{
    'workoutName': clip(workout.name, 80),
    if (description.isNotEmpty) 'description': clip(description, 4096),
    'sportType': sport,
    'workoutSegments': [
      {'segmentOrder': 1, 'sportType': sport, 'workoutSteps': steps},
    ],
  };
  return GarminExport(
    payload,
    workout.inputs,
    warnings.toSet().toList(),
    problems.toSet().toList(),
  );
}
