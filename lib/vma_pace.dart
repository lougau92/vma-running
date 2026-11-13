import 'running/running.dart'
    show
        RunningSpeed,
        RunningSplit,
        isPositiveFinite,
        formatPacePerKm,
        formatRunningDuration;

class VmaPaceEntry {
  const VmaPaceEntry({required this.percent, required this.split});

  final double percent;
  final RunningSplit split;

  double get speedKmh => split.speed.kmh;
  String get pacePerKm => formatPacePerKm(split.speed);
  String get timeForDistance => formatRunningDuration(split.seconds);
}

/// Selects percentage rows; shared running math derives each row's values.
class VmaPaceCalculator {
  List<VmaPaceEntry> buildTable(
    double vma, {
    required double minPercent,
    required double maxPercent,
    required double step,
    required double distanceMeters,
  }) {
    if (![minPercent, maxPercent, step].every(isPositiveFinite) ||
        minPercent > maxPercent ||
        minPercent + step <= minPercent) {
      return [];
    }
    final entries = <VmaPaceEntry>[];
    for (double percent = minPercent; percent <= maxPercent; percent += step) {
      final split = RunningSpeed.fromVma(
        vma,
        percent,
      )?.forDistance(distanceMeters);
      if (split == null) return [];
      entries.add(VmaPaceEntry(percent: percent, split: split));
    }
    return entries;
  }
}
