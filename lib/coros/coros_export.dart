import '../app_localizations.dart';
import '../watch/watch_workout.dart';

class CorosExport {
  const CorosExport(this.course, this.warnings, this.problems);
  final Map<String, dynamic> course;
  final List<String> warnings, problems;
}

CorosExport buildCorosExport(
  ResolvedWatchWorkout workout,
  AppLocalizations strings,
) {
  final notes = <String>{
    if (workout.description.trim().isNotEmpty) workout.description.trim(),
  };
  final warnings = {...workout.warnings};
  final problems = {...workout.problems};
  final sections = <Map<String, dynamic>>[];
  var expanded = 0;

  Map<String, dynamic> section(ResolvedWatchStep step) {
    notes.addAll(step.notes.where((note) => note.trim().isNotEmpty));
    final target = switch (step.end) {
      'distance' => 1,
      'time' => 2,
      'manual' => 4,
      _ => null,
    };
    if (target == null) problems.add(strings['coros_end_unsupported']);
    final amount = step.amount;
    final value = amount?.isFinite == true ? amount!.round() : null;
    if ((target == 1 || target == 2) &&
        (value == null || value < 1 || value > 2147483647)) {
      problems.add(strings['coros_end_unsupported']);
    }
    if (value != null && value != amount) {
      warnings.add(strings['coros_rounded']);
    }
    int? pace(double? speed) {
      if (speed == null) return null;
      final seconds = 1000 / speed;
      if (seconds.isFinite && seconds >= 119.5 && seconds < 1499.5) {
        return seconds.round();
      }
      problems.add(strings['coros_pace_bounds']);
      return null;
    }

    final fast = pace(step.fastSpeed), slow = pace(step.slowSpeed);
    return {
      'sectionType': switch (step.role) {
        'warmup' => 1,
        'recovery' || 'rest' => 3,
        'cooldown' => 4,
        _ => 2,
      },
      if (target != null) 'targetType': target,
      if (value != null) 'targetValue': value,
      if (fast != null && slow != null) ...{
        'intensityType': 2,
        'intensityValueStart': fast,
        'intensityValueEnd': slow,
      },
    };
  }

  bool groupable(List<ResolvedWatchNode> nodes) => nodes.every(
    (node) =>
        node is ResolvedWatchStep &&
        !['warmup', 'cooldown'].contains(node.role),
  );

  void append(List<ResolvedWatchNode> nodes) {
    for (final node in nodes) {
      if (expanded > 200) return;
      switch (node) {
        case ResolvedWatchStep():
          expanded++;
          sections.add(section(node));
        case ResolvedWatchRepeat():
          final repetitions = node.between.isEmpty
              ? node.count
              : node.count - 1;
          final cycle = [...node.body, ...node.between];
          if (repetitions > 1 &&
              repetitions <= 20 &&
              cycle.isNotEmpty &&
              groupable(cycle)) {
            expanded += repetitions * cycle.length;
            sections.add({
              'intervalGroup': true,
              'repeats': repetitions,
              'sets': [
                for (final step in cycle) section(step as ResolvedWatchStep),
              ],
            });
            if (node.between.isNotEmpty) append(node.body);
          } else {
            for (var i = 0; i < node.count && expanded <= 200; i++) {
              append(node.body);
              if (i < node.count - 1) append(node.between);
            }
          }
      }
    }
  }

  append(workout.nodes);
  if (sections.isEmpty) problems.add(strings['garmin_empty']);
  if (expanded > 200) problems.add(strings['garmin_too_many']);
  final name = workout.name.trim();
  final description = notes.isEmpty ? name : notes.join('\n');
  if (name.runes.length > 100) warnings.add(strings['coros_title_shortened']);
  if (description.runes.length > 4096) {
    problems.add(strings['coros_notes_limit']);
  }
  return CorosExport(
    {
      'sportType': 1,
      'courseName': String.fromCharCodes(name.runes.take(100)),
      'courseDescription': description,
      'sections': sections,
    },
    warnings.toList(),
    problems.toList(),
  );
}
