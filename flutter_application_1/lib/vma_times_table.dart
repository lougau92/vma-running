import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'distance_input.dart';
import 'time_utils.dart';

class VmaTimesTable extends StatelessWidget {
  const VmaTimesTable({
    super.key,
    required this.vma,
    required this.minDistanceMeters,
    required this.maxDistanceMeters,
    required this.onEditDistances,
  });

  final double vma;
  final double minDistanceMeters;
  final double maxDistanceMeters;
  final VoidCallback onEditDistances;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final distances = _buildDistances();
    final speedMs = vma * 1000 / 3600;

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 400),
            child: DataTable(
              columns: [
                DataColumn(
                  label: InkWell(
                    onTap: onEditDistances,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(strings.distance),
                    ),
                  ),
                ),
                DataColumn(label: Text(strings.time)),
                DataColumn(label: Text(strings.avgPace)),
              ],
              rows: distances
                  .map(
                    (distance) => DataRow(
                      cells: [
                        DataCell(Text(_formatDistance(distance, strings))),
                        DataCell(Text(_formatDistanceTime(speedMs, distance))),
                        DataCell(Text(formatPacePerKm(vma))),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDistanceTime(double speedMs, double distanceMeters) {
    if (speedMs <= 0 || distanceMeters <= 0) return '-';
    final speedKmh = speedMs * 3.6;
    return formatTimeForDistance(speedKmh, distanceMeters);
  }

  List<double> _buildDistances() {
    final distances = <double>[];
    if (minDistanceMeters <= 0 || maxDistanceMeters <= 0) {
      return distances;
    }

    void addRange(double start, double end, double step) {
      for (double d = start; d <= end + 0.0001; d += step) {
        distances.add(d);
        if (distances.length > 2000) break;
      }
    }

    addRange(100, 500, 100); // 100m increments up to 500
    addRange(500, 3000, 500); // 500m increments to 3k
    addRange(3000, 15000, 1000); // 1k increments 3k-15k
    addRange(20000, 50000, 5000); // 5k increments 20k-50k

    // Half and full marathon.
    distances.addAll([21097.5, 42195]);

    addRange(50000, 200000, 10000); // 10k increments 50k+

    distances.sort();

    final unique = <double>[];
    for (final d in distances) {
      if (unique.isEmpty || (d - unique.last).abs() > 0.0001) {
        unique.add(d);
      }
    }

    return unique
        .where((d) => d >= minDistanceMeters && d <= maxDistanceMeters)
        .toList();
  }

  String _formatDistance(double meters, AppLocalizations strings) {
    if ((meters - kMarathonMeters).abs() <= 1) {
      return strings.marathon;
    }
    if ((meters - kHalfMarathonMeters).abs() <= 2) {
      return strings.halfMarathon;
    }
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(km % 1 == 0 ? 0 : 1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}
