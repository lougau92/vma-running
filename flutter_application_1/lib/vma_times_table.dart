import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'presets.dart';
import 'time_utils.dart';

class VmaTimesTable extends StatefulWidget {
  const VmaTimesTable({
    super.key,
    required this.speedKmh,
    required this.minDistanceMeters,
    required this.maxDistanceMeters,
    required this.minTimeSeconds,
    required this.maxTimeSeconds,
    required this.onEditDistances,
    required this.onEditTimes,
  });

  final double speedKmh;
  final double minDistanceMeters;
  final double maxDistanceMeters;
  final double minTimeSeconds;
  final double maxTimeSeconds;
  final VoidCallback onEditDistances;
  final VoidCallback onEditTimes;

  @override
  State<VmaTimesTable> createState() => _VmaTimesTableState();
}

class _VmaTimesTableState extends State<VmaTimesTable> {
  bool _distanceFirst = true;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final data = _distanceFirst ? _buildDistances() : _buildTimes();
    final speedMs = widget.speedKmh * 1000 / 3600;

    final distanceHeader = SizedBox(
      width: 150,
      child: InkWell(
        onTap: _distanceFirst ? widget.onEditDistances : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(strings.distance, overflow: TextOverflow.ellipsis),
        ),
      ),
    );

    final timeHeader = SizedBox(
      width: 110,
      child: InkWell(
        onTap: !_distanceFirst ? widget.onEditTimes : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(strings.time, overflow: TextOverflow.ellipsis),
        ),
      ),
    );

    final swapColumn = DataColumn(
      label: SizedBox(
        width: 36,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => setState(() => _distanceFirst = !_distanceFirst),
          icon: const Icon(Icons.swap_horiz),
          tooltip: '${strings.distance} ⇄ ${strings.time}',
        ),
      ),
    );

    final distanceColumn = DataColumn(label: distanceHeader);
    final timeColumn = DataColumn(label: timeHeader);

    final columns = [
      swapColumn,
      _distanceFirst ? distanceColumn : timeColumn,
      _distanceFirst ? timeColumn : distanceColumn,
    ];

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320),
            child: DataTable(
              columnSpacing: 16,
              columns: columns,
              rows: data
                  .map(
                    (value) => DataRow(
                      cells: _distanceFirst
                          ? _buildDistanceRow(value, speedMs, strings)
                          : _buildTimeRow(value, speedMs, strings),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  List<DataCell> _buildDistanceRow(
    double distanceMeters,
    double speedMs,
    AppLocalizations strings,
  ) {
    final distanceCell =
        DataCell(Text(strings.distanceShort(distanceMeters)));
    final timeCell = DataCell(Text(_formatDistanceTime(speedMs, distanceMeters)));
    const spacer = DataCell(SizedBox.shrink());
    return [spacer, distanceCell, timeCell];
  }

  List<DataCell> _buildTimeRow(
    double seconds,
    double speedMs,
    AppLocalizations strings,
  ) {
    final timeCell = DataCell(Text(formatElapsed(seconds.toInt())));
    final distance = speedMs * seconds;
    final distanceCell = DataCell(Text(strings.distanceShort(distance)));
    const spacer = DataCell(SizedBox.shrink());
    return [spacer, timeCell, distanceCell];
  }

  String _formatDistanceTime(double speedMs, double distanceMeters) {
    if (speedMs <= 0 || distanceMeters <= 0) return '-';
    final speedKmh = speedMs * 3.6;
    return formatTimeForDistance(speedKmh, distanceMeters);
  }

  List<double> _buildDistances() {
    final distances = presetDistances();
    return distances
        .where((d) => d >= widget.minDistanceMeters && d <= widget.maxDistanceMeters)
        .toList();
  }

  List<double> _buildTimes() {
    final times = presetTimesSeconds();
    return times
        .where((t) => t >= widget.minTimeSeconds && t <= widget.maxTimeSeconds)
        .toList();
  }
}
