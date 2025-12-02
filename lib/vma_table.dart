import 'package:flutter/material.dart';
import 'app_localizations.dart';
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
    final strings = AppLocalizations.of(context);
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(strings.intensity),
                    ),
                  ),
                ),
                DataColumn(label: Text(strings.pacePerKm)),
                DataColumn(
                  label: InkWell(
                    onTap: onEditDistance,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(strings.timeForDistanceLabel(distanceMeters)),
                    ),
                  ),
                ),
                DataColumn(label: Text(strings.speedKmh)),
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
