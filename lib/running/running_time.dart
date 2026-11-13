/// Time and pace parsing/formatting for the shared running model.
library;

import 'running_speed.dart' show RunningSpeed;

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Formats pace per kilometer from speed in km/h (e.g. 03:45 or 03:45 /km).
String formatPacePerKm(RunningSpeed? speed, {bool includeUnit = false}) {
  if (speed == null) return '-';
  final pace = speed.paceSecondsPerKm;
  if (pace < 1 || pace > 315360000) {
    final base = formatRunningDuration(pace);
    return includeUnit ? '$base /km' : base;
  }
  final totalSeconds = pace.round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final base = '${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  return includeUnit ? '$base /km' : base;
}

/// Formats a numeric duration without changing the underlying calculation.
String formatRunningDuration(double? seconds) {
  if (seconds == null || !seconds.isFinite || seconds < 0) return '-';
  if (seconds > 0 && (seconds < 0.01 || seconds > 315360000)) {
    return '${seconds.toStringAsExponential(2)} s';
  }
  if (seconds > 0 && seconds < 1) return '${seconds.toStringAsFixed(2)} s';
  return formatElapsed(seconds.round());
}

/// Formats an elapsed time in seconds into a compact human-friendly string.
/// Examples:
/// - 75s -> 01:15
/// - 3670s -> 1:01:10
/// - 1 day, 3h, 5m -> 1d 03:05:00
String formatElapsed(int totalSeconds) {
  if (totalSeconds < 0) return '-';
  final days = totalSeconds ~/ 86400;
  final hours = (totalSeconds % 86400) ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (days > 0) {
    return '${days}d ${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }
  if (hours > 0) {
    return '$hours:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }
  return '${_twoDigits(minutes)}:${_twoDigits(seconds)}';
}

/// Parses seconds, mm:ss, or h:mm:ss. Bare numbers mean seconds.
/// Set [allowHours] to false for a min:sec pace input. Decimal commas work too.
/// Zero is valid for durations such as recovery; callers validate their context.
double? parseRunningDuration(String text, {bool allowHours = true}) {
  final parts = text.trim().replaceAll(',', '.').split(':');
  if (parts.length > (allowHours ? 3 : 2) ||
      parts.any((p) => !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(p))) {
    return null;
  }
  final values = parts.map(double.parse).toList();
  for (var i = 0; i < values.length; i++) {
    if (!values[i].isFinite || (i > 0 && values[i] >= 60)) return null;
    if (i < values.length - 1 && values[i] % 1 != 0) return null;
  }
  final seconds = values.fold<double>(0, (total, part) => total * 60 + part);
  return seconds.isFinite ? seconds : null;
}
