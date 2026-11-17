import '../app_localizations.dart';
import '../workouts/workout.dart';
import '../workouts/workout_format.dart';

class ExportInput {
  ExportInput(
    this.path,
    this.label, {
    this.bounds,
    this.options,
    this.resolved = false,
    this.integer = false,
  });
  final bool resolved, integer;
  final String path, label;
  final Bounds? bounds;
  final List<String>? options;
}

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
  List<WorkoutNote> notes = const [],
}) {
  final inputs = <ExportInput>[];
  final warnings = <String>[];
  final problems = <String>[];
  final steps = <Map<String, dynamic>>[];
  var visits = 0;
  String clip(String text, int max) {
    final chars = text.runes.toList();
    if (chars.length <= max) return text;
    warnings.add(s['garmin_shortened']);
    return '${String.fromCharCodes(chars.take(max - 1))}…';
  }

  double resolve(Bounds b, String path, String label, {bool integer = false}) {
    if (b.min == b.max) return b.min;
    final value = values.containsKey(path) ? values[path] : b.max;
    final valid =
        value != null &&
        value.isFinite &&
        value >= b.min &&
        value <= b.max &&
        (!integer || value == value.roundToDouble());
    inputs.add(
      ExportInput(path, label, bounds: b, resolved: valid, integer: integer),
    );
    return valid ? value : b.max;
  }

  void walk(
    WorkoutNode node,
    String path,
    String phase,
    List<String> inherited,
  ) {
    if (++visits > 10000) {
      problems.add(s['garmin_too_many']);
      return;
    }
    if (steps.length > 200) return;
    if (node.optional) {
      inputs.add(
        ExportInput(
          '$path/optional',
          node.label ?? s['garmin_optional'],
          options: [s['garmin_include'], s['garmin_exclude']],
          resolved: true,
        ),
      );
      if (values['$path/optional'] == 1) return;
    }
    final context = [
      ...inherited,
      if (node.label != null) node.label!,
      ...node.notes.map((n) => n.text),
    ];
    switch (node) {
      case WorkoutSequence():
        for (var i = 0; i < node.children.length; i++) {
          walk(node.children[i], '$path/children/$i', phase, context);
        }
      case WorkoutRepeat():
        final count = node.count.max.toInt();
        if (node.count.min != node.count.max) {
          warnings.add('${s['garmin_max_repetitions']}: $count');
        }
        for (
          var i = 0;
          i < count && steps.length <= 200 && visits <= 10000;
          i++
        ) {
          walk(node.body, '$path/body', phase, context);
          if (i < count - 1 && node.between != null) {
            walk(node.between!, '$path/between', phase, context);
          }
        }
      case WorkoutChoice():
        final selected = values[path];
        final valid =
            selected != null &&
            selected.isFinite &&
            selected == selected.roundToDouble() &&
            selected >= 0 &&
            selected < node.options.length;
        inputs.add(
          ExportInput(
            path,
            node.reason,
            options: node.options.map((o) => o.label).toList(),
            resolved: valid,
          ),
        );
        if (valid) {
          final option = node.options[selected.toInt()];
          walk(option.plan, '$path/options/${selected.toInt()}', phase, [
            ...context,
            option.label,
          ]);
        }
      case WorkoutStep():
        final end = node.end;
        double? amount;
        String endKey;
        int endId;
        switch (end.kind) {
          case 'manual':
            endKey = 'lap.button';
            endId = 1;
          case 'time':
            endKey = 'time';
            endId = 2;
            amount = resolve(
              end.quantity!,
              '$path/end',
              '${node.label ?? (phase == 'warmup'
                      ? s.warmup
                      : phase == 'cooldown'
                      ? s.cooldown
                      : s.sessionContent)} · ${s['garmin_seconds']}',
            );
          case 'distance':
            endKey = 'distance';
            endId = 3;
            amount = resolve(
              end.quantity!,
              '$path/end',
              '${node.label ?? (phase == 'warmup'
                      ? s.warmup
                      : phase == 'cooldown'
                      ? s.cooldown
                      : s.sessionContent)} · ${s['garmin_metres']}',
            );
          case 'laps':
            endKey = 'distance';
            endId = 3;
            amount =
                resolve(
                  end.quantity!,
                  '$path/end',
                  '${node.label ?? (phase == 'warmup'
                          ? s.warmup
                          : phase == 'cooldown'
                          ? s.cooldown
                          : s.sessionContent)} · ${s['workout_laps']}',
                  integer: true,
                ) *
                (end.lapLength ?? 400);
            if (end.lapLength == null) warnings.add(s['garmin_default_lap']);
          default:
            final selected = values['$path/manual_end'];
            inputs.add(
              ExportInput(
                '$path/manual_end',
                '${s['garmin_unsupported_end']}: ${formatWorkoutEnd(end, s)}',
                options: [s['garmin_finish_lap']],
                resolved: selected == 0,
              ),
            );
            if (selected != 0) return;
            endKey = 'lap.button';
            endId = 1;
        }
        if (amount != null && (!amount.isFinite || amount <= 0)) {
          problems.add(s['garmin_unsupported_end']);
        }
        final description = [
          ...context,
          if (!['manual', 'time', 'distance', 'laps'].contains(end.kind))
            formatWorkoutEnd(end, s),
          if (node.movement != null) formatWorkoutMovement(node.movement, s),
          ...node.targets.map((t) => formatWorkoutTarget(t, s, vma)),
        ];
        double? slow, fast;
        var paceTargets = 0;
        for (final target in node.targets) {
          if (target.kind == 'numeric' &&
              [
                'vma_percent',
                'speed_mps',
                'pace_seconds_per_km',
              ].contains(target.metric)) {
            paceTargets++;
            final b = target.value!;
            if (b.min <= 0 ||
                (target.metric == 'vma_percent' &&
                    (!vma.isFinite || vma <= 0))) {
              problems.add(s['garmin_invalid_target']);
              continue;
            }
            switch (target.metric) {
              case 'vma_percent':
                slow = vma * b.min / 360;
                fast = vma * b.max / 360;
              case 'speed_mps':
                slow = b.min;
                fast = b.max;
              case 'pace_seconds_per_km':
                slow = 1000 / b.max;
                fast = 1000 / b.min;
            }
          } else {
            warnings.add(s['garmin_instruction_target']);
          }
        }
        if ((fast != null && !fast.isFinite) ||
            (slow != null && (!slow.isFinite || slow <= 0))) {
          problems.add(s['garmin_invalid_target']);
        }
        if (paceTargets > 1) problems.add(s['garmin_invalid_target']);
        final type = node.role == 'recovery'
            ? (node.movement?.mode == 'passive' ? 'rest' : 'recovery')
            : phase == 'warmup'
            ? 'warmup'
            : phase == 'cooldown'
            ? 'cooldown'
            : 'interval';
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

  for (final entry in {
    'warmup': version.warmup,
    'main': version.main,
    'cooldown': version.cooldown,
  }.entries) {
    if (entry.value.plan != null) {
      walk(entry.value.plan!, entry.key, entry.key, []);
    }
  }
  if (steps.isEmpty) problems.add(s['garmin_empty']);
  if (steps.length > 200) problems.add(s['garmin_too_many']);
  final sport = {'sportTypeId': 1, 'sportTypeKey': 'running'};
  final description = [
    ...notes,
    ...session.notes,
    ...version.notes,
  ].map((n) => n.text).join('\n');
  final payload = <String, dynamic>{
    'workoutName': clip('${session.title} · ${version.label}', 80),
    if (description.isNotEmpty) 'description': clip(description, 4096),
    'sportType': sport,
    'workoutSegments': [
      {'segmentOrder': 1, 'sportType': sport, 'workoutSteps': steps},
    ],
  };
  final unique = <String, ExportInput>{};
  for (final input in inputs) {
    unique[input.path] = input;
  }
  return GarminExport(
    payload,
    unique.values.toList(),
    warnings.toSet().toList(),
    problems.toSet().toList(),
  );
}
