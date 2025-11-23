String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// Formats pace per kilometer from speed in km/h (e.g. 03:45 or 03:45 /km).
String formatPacePerKm(double speedKmh, {bool includeUnit = false}) {
  if (speedKmh <= 0) return '-';
  final totalSeconds = (3600 / speedKmh).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  final base = '${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  return includeUnit ? '$base /km' : base;
}

/// Formats the time needed to cover a distance (in meters) at a given speed in km/h.
String formatTimeForDistance(
  double speedKmh,
  double distanceMeters, {
  bool includeUnit = false,
}) {
  if (speedKmh <= 0 || distanceMeters <= 0) return '-';
  final speedMs = speedKmh * 1000 / 3600;
  final totalSeconds = (distanceMeters / speedMs).round();
  final base = formatElapsed(totalSeconds);
  if (!includeUnit) return base;

  final kmValue = distanceMeters / 1000;
  final unitLabel = kmValue >= 1
      ? '${kmValue.toStringAsFixed(kmValue % 1 == 0 ? 0 : 1)} km'
      : '${distanceMeters.toStringAsFixed(0)} m';
  return '$base ($unitLabel)';
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
