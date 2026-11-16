import '../app_localizations.dart';
import '../running.dart';
import 'workout.dart';

String workoutNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String workoutRange(Bounds b, [String Function(double)? format]) {
  final f = format ?? workoutNumber;
  return b.min == b.max ? f(b.min) : '${f(b.min)}–${f(b.max)}';
}

String workoutTime(double value) {
  if (value % 60 == 0) return '${workoutNumber(value / 60)} min';
  if (value < 60) return '${workoutNumber(value)} s';
  return '${value ~/ 60} min ${workoutNumber(value % 60)} s';
}

String formatWorkoutEnd(
  WorkoutEnd end,
  AppLocalizations s,
) => switch (end.kind) {
  'time' => workoutRange(end.quantity!, workoutTime),
  'distance' => '${workoutRange(end.quantity!)} m',
  'laps' =>
    '${workoutRange(end.quantity!)} ${s['workout_laps']}${end.lapLength == null ? '' : ' × ${workoutNumber(end.lapLength!)} m'}',
  'repetitions' => '${workoutRange(end.quantity!)} ${s['workout_repetitions']}',
  'manual' => s['workout_manual'],
  'event' => end.description!,
  'unknown' => '${s['workout_unknown']}: ${end.description}',
  'any_of' || 'all_of' =>
    '(${end.conditions.map((c) => formatWorkoutEnd(c, s)).join(' ${s[end.kind == 'any_of' ? 'workout_or' : 'workout_and']} ')})',
  _ => throw const FormatException('Unsupported endpoint'),
};
String _metric(String metric, AppLocalizations s) => switch (metric) {
  'vma_percent' => '% VMA',
  'speed_mps' => 'm/s',
  'pace_seconds_per_km' => '/km',
  'heart_rate_bpm' => 'bpm',
  'heart_rate_max_percent' => s['workout_max_hr'],
  'power_watts' => 'W',
  'cadence_spm' => s['workout_spm'],
  'rpe_0_10' => 'RPE /10',
  _ => throw const FormatException('Unsupported metric'),
};
String _targetValue(double v, String metric) => metric == 'pace_seconds_per_km'
    ? formatRunningDuration(v)
    : workoutNumber(v);
String formatWorkoutTarget(WorkoutTarget t, AppLocalizations s, double vma) {
  if (t.kind == 'effort') return t.text!;
  final metric = t.metric!;
  final unit = _metric(metric, s);
  if (t.kind == 'progression') {
    final progression =
        '${_targetValue(t.from!, metric)} → ${_targetValue(t.to!, metric)} $unit';
    return '$progression · ${s[t.scope == 'within_step' ? 'workout_within_step' : 'workout_across_iterations']} · ${s[t.distribution == 'linear' ? 'workout_linear' : 'workout_distribution_unspecified']}';
  }
  final value = workoutRange(t.value!, (v) => _targetValue(v, metric));
  final prescription = '${t.approximate ? '≈ ' : ''}$value $unit';
  if (metric != 'vma_percent' ||
      !vma.isFinite ||
      vma <= 0 ||
      t.value!.min <= 0) {
    return prescription;
  }
  String pace(double percent) =>
      formatPacePerKm(RunningSpeed.fromVma(vma, percent));
  final paceRange = t.value!.min == t.value!.max
      ? pace(t.value!.min)
      : '${pace(t.value!.max)}–${pace(t.value!.min)}';
  return '$prescription · $paceRange /km';
}

String formatWorkoutMovement(WorkoutMovement? movement, AppLocalizations s) {
  final mode = movement?.mode ?? 'unspecified';
  final text = s['workout_movement_$mode'];
  final allowed = movement?.allowed ?? [];
  return allowed.isEmpty
      ? text
      : '$text · ${allowed.map((m) => s['workout_move_$m']).join(' / ')}';
}
