import 'time_utils.dart';

class VmaPaceEntry {
  const VmaPaceEntry({
    required this.percent,
    required this.speedKmh,
    required this.pacePerKm,
    required this.timeForDistance,
  });

  final double percent;
  final double speedKmh;
  final String pacePerKm;
  final String timeForDistance;
}

/// Creates pace entries for a given VMA using percentage steps.
class VmaPaceCalculator {
  List<VmaPaceEntry> buildTable(
    double vma, {
    required double minPercent,
    required double maxPercent,
    required double step,
    required double distanceMeters,
  }) {
    final entries = <VmaPaceEntry>[];
    for (double percent = minPercent;
        percent <= maxPercent;
        percent += step) {
      final speed = vma * (percent / 100);
      entries.add(
        VmaPaceEntry(
          percent: percent,
          speedKmh: speed,
          pacePerKm: formatPacePerKm(speed),
          timeForDistance: formatTimeForDistance(speed, distanceMeters),
        ),
      );
    }
    return entries;
  }
}
