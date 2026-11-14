/// Shared, unrounded running math. Distances are meters and durations seconds.
/// Invalid or unrepresentable values return null at the domain boundary.
class RunningSpeed {
  const RunningSpeed._(this.kmh);

  final double kmh;

  static RunningSpeed? fromKmh(double? kmh) {
    if (!isPositiveFinite(kmh) || !isPositiveFinite(3600 / kmh!)) return null;
    return RunningSpeed._(kmh);
  }

  static RunningSpeed? fromPaceSeconds(double? secondsPerKm) =>
      isPositiveFinite(secondsPerKm) ? fromKmh(3600 / secondsPerKm!) : null;

  static RunningSpeed? fromVma(double? vmaKmh, double percent) =>
      isPositiveFinite(vmaKmh) && isPositiveFinite(percent)
      ? fromKmh(vmaKmh! * (percent / 100))
      : null;

  static RunningSpeed? fromDistanceAndTime({
    required double distanceMeters,
    required double seconds,
  }) => isPositiveFinite(distanceMeters) && isPositiveFinite(seconds)
      ? fromKmh(distanceMeters / seconds * 3.6)
      : null;

  double get paceSecondsPerKm => 3600 / kmh;
  double get metersPerSecond => kmh / 3.6;

  double? percentOfVma(double? vmaKmh) =>
      isPositiveFinite(vmaKmh) ? _positive(kmh / vmaKmh! * 100) : null;

  RunningSplit? forDistance(double meters) {
    if (!isPositiveFinite(meters)) return null;
    final seconds = _positive(meters / metersPerSecond);
    return seconds == null ? null : RunningSplit._(this, meters, seconds);
  }

  RunningSplit? forDuration(double seconds) {
    if (!isPositiveFinite(seconds)) return null;
    final meters = _positive(metersPerSecond * seconds);
    return meters == null ? null : RunningSplit._(this, meters, seconds);
  }
}

/// A distance and duration at a constant speed; never contains rounded values.
class RunningSplit {
  const RunningSplit._(this.speed, this.distanceMeters, this.seconds);

  final RunningSpeed speed;
  final double distanceMeters;
  final double seconds;

  double get distanceKm => distanceMeters / 1000;
}

bool isPositiveFinite(double? value) =>
    value != null && value.isFinite && value > 0;

double? _positive(double value) => isPositiveFinite(value) ? value : null;
