import 'package:flutter/material.dart';
import 'package:flutter_application_1/distance_extensions.dart';
import 'vma_pace.dart';

class VmaPaceTable extends StatelessWidget {
  const VmaPaceTable({
    super.key,
    required this.entries,
    required this.onEditPercentages,
    required this.distanceMeters,
    required this.onEditDistance,
  });

  final List<VmaPaceEntry> entries;
  final VoidCallback onEditPercentages;
  final double distanceMeters;
  final VoidCallback onEditDistance;

  @override
  Widget build(BuildContext context) {
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
                    onTap: onEditPercentages,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Intensity'),
                    ),
                  ),
                ),
                const DataColumn(label: Text('Pace /km')),
                DataColumn(
                  label: InkWell(
                    onTap: onEditDistance,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(distanceMeters.toRaceLabel()),
                    ),
                  ),
                ),
                const DataColumn(label: Text('Speed (km/h)')),
              ],
              rows: entries
                  .map(
                    (entry) => DataRow(
                      cells: [
                        DataCell(Text('${entry.percent.toStringAsFixed(0)}%')),
                        DataCell(Text(entry.pacePerKm)),
                        DataCell(Text(entry.timeForDistance)),
                        DataCell(Text(entry.speedKmh.toStringAsFixed(2))),
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
}
