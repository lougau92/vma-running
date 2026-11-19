import '../app_localizations.dart';
import '../workouts/workout.dart';
import '../workouts/workout_format.dart';

class ExportInput {
  const ExportInput(
    this.path,
    this.label, {
    this.bounds,
    this.options,
    this.resolved = false,
    this.value,
  });
  final bool resolved;
  final double? value;
  final String path, label;
  final Bounds? bounds;
  final List<String>? options;
}

sealed class ResolvedWatchNode {
  const ResolvedWatchNode();
}

class ResolvedWatchStep extends ResolvedWatchNode {
  const ResolvedWatchStep(
    this.phase,
    this.role,
    this.end,
    this.amount,
    this.slowSpeed,
    this.fastSpeed,
    this.notes,
  );

  final String phase, role, end;
  final double? amount, slowSpeed, fastSpeed;
  final List<String> notes;
}

class ResolvedWatchRepeat extends ResolvedWatchNode {
  const ResolvedWatchRepeat(this.count, this.body, this.between);
  final int count;
  final List<ResolvedWatchNode> body, between;
}

class ResolvedWatchWorkout {
  const ResolvedWatchWorkout(
    this.name,
    this.description,
    this.nodes,
    this.inputs,
    this.warnings,
    this.problems,
  );

  final String name, description;
  final List<ResolvedWatchNode> nodes;
  final List<ExportInput> inputs;
  final List<String> warnings, problems;
}

/// Resolution values are export-only. The source plan is never modified.
ResolvedWatchWorkout resolveWatchWorkout(
  WorkoutSession session,
  WorkoutVersion version,
  double vma,
  AppLocalizations s, {
  Map<String, double> values = const {},
  bool defaultChoices = false,
  List<WorkoutNote> notes = const [],
}) {
  final inputs = <String, ExportInput>{};
  final warnings = <String>[];
  final problems = <String>[];
  var visits = 0;

  double resolve(Bounds b, String path, String label, {bool integer = false}) {
    if (b.min == b.max) return b.min;
    final value = values[path] ?? b.max;
    final valid =
        value.isFinite &&
        value >= b.min &&
        value <= b.max &&
        (!integer || value == value.roundToDouble());
    inputs[path] = ExportInput(
      path,
      label,
      bounds: b,
      resolved: valid,
      value: value,
    );
    return valid ? value : b.max;
  }

  List<ResolvedWatchNode> walk(
    WorkoutNode node,
    String path,
    String phase,
    List<String> inherited,
  ) {
    if (++visits > 10000) {
      problems.add(s['garmin_too_many']);
      return const [];
    }
    if (node.optional) {
      final pathKey = '$path/optional';
      final selection = values[pathKey] ?? 0;
      inputs[pathKey] = ExportInput(
        pathKey,
        node.label ?? s['garmin_optional'],
        options: [s['garmin_include'], s['garmin_exclude']],
        resolved: true,
        value: selection == 1 ? 1 : 0,
      );
      if (selection == 1) return const [];
    }
    final context = [
      ...inherited,
      if (node.label != null) node.label!,
      ...node.notes.map((n) => n.text),
    ];
    switch (node) {
      case WorkoutSequence():
        return [
          for (var i = 0; i < node.children.length; i++)
            ...walk(node.children[i], '$path/children/$i', phase, context),
        ];
      case WorkoutRepeat():
        final count = node.count.max.toInt();
        if (node.count.min != node.count.max) {
          warnings.add('${s['garmin_max_repetitions']}: $count');
        }
        final body = walk(node.body, '$path/body', phase, context);
        final between = count > 1 && node.between != null
            ? walk(node.between!, '$path/between', phase, context)
            : const <ResolvedWatchNode>[];
        if (count < 1 || (body.isEmpty && between.isEmpty)) return const [];
        return [ResolvedWatchRepeat(count, body, between)];
      case WorkoutChoice():
        final selected = values[path] ?? (defaultChoices ? 0.0 : null);
        final valid =
            selected != null &&
            selected.isFinite &&
            selected == selected.roundToDouble() &&
            selected >= 0 &&
            selected < node.options.length;
        inputs[path] = ExportInput(
          path,
          node.reason,
          options: node.options.map((option) => option.label).toList(),
          resolved: valid,
          value: valid ? selected : null,
        );
        if (valid) {
          final option = node.options[selected.toInt()];
          return walk(option.plan, '$path/options/${selected.toInt()}', phase, [
            ...context,
            option.label,
          ]);
        }
        return const [];
      case WorkoutStep():
        final end = node.end;
        final unit = switch (end.kind) {
          'time' => s['garmin_seconds'],
          'distance' => s['garmin_metres'],
          'laps' => s['workout_laps'],
          _ => null,
        };
        final endKind = switch (end.kind) {
          'laps' => 'distance',
          'time' || 'distance' || 'manual' => end.kind,
          _ => 'descriptive',
        };
        double? amount;
        if (unit != null) {
          final label =
              node.label ??
              switch (phase) {
                'warmup' => s.warmup,
                'cooldown' => s.cooldown,
                _ => s.sessionContent,
              };
          final laps = end.kind == 'laps';
          amount = resolve(
            end.quantity!,
            '$path/end',
            '$label · $unit',
            integer: laps,
          );
          if (laps) {
            amount *= end.lapLength ?? 400;
            if (end.lapLength == null) warnings.add(s['garmin_default_lap']);
          }
        }
        if (amount != null && (!amount.isFinite || amount <= 0)) {
          problems.add(s['garmin_unsupported_end']);
        }
        final description = [
          ...context,
          if (endKind == 'descriptive') formatWorkoutEnd(end, s),
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
        return [
          ResolvedWatchStep(
            phase,
            type,
            endKind,
            amount,
            slow,
            fast,
            description,
          ),
        ];
    }
  }

  final nodes = <ResolvedWatchNode>[];
  for (final entry in {
    'warmup': version.warmup,
    'main': version.main,
    'cooldown': version.cooldown,
  }.entries) {
    if (entry.value.plan != null) {
      nodes.addAll(walk(entry.value.plan!, entry.key, entry.key, []));
    }
  }
  final description = [
    ...notes,
    ...session.notes,
    ...version.notes,
  ].map((note) => note.text).join('\n');
  return ResolvedWatchWorkout(
    '${session.title} · ${version.label}',
    description,
    nodes,
    inputs.values.toList(),
    warnings,
    problems,
  );
}
