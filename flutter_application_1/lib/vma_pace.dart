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
    double minPercent = 50,
    double maxPercent = 120,
    double step = 5,
    double distanceMeters = 400,
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
          pacePerKm: _formatPace(speed),
          timeForDistance: _formatDistanceTime(speed, distanceMeters),
        ),
      );
    }
    return entries;
  }

  String _formatPace(double speedKmh) {
    if (speedKmh <= 0) return '-';
    final totalSeconds = (3600 / speedKmh).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDistanceTime(double speedKmh, double distanceMeters) {
    if (speedKmh <= 0 || distanceMeters <= 0) return '-';
    final speedMs = speedKmh * 1000 / 3600;
    final totalSeconds = (distanceMeters / speedMs).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
