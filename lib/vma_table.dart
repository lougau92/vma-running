import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'interactive_header.dart';
import 'vma_pace.dart';

class VmaPaceTable extends StatefulWidget {
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
  State<VmaPaceTable> createState() => _VmaPaceTableState();
}

class _VmaPaceTableState extends State<VmaPaceTable> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return Scrollbar(
      thumbVisibility: true,
      controller: _verticalController,
      child: SingleChildScrollView(
        controller: _verticalController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 400),
            child: DataTable(
              columns: [
                DataColumn(
                  label: InteractiveHeader(
                    label: strings.intensity,
                    onTap: widget.onEditPercentages,
                    tooltip: strings.intensity,
                  ),
                ),
                DataColumn(label: Text(strings.pacePerKm)),
                DataColumn(
                  label: InteractiveHeader(
                    label:
                        strings.timeForDistanceLabel(widget.distanceMeters),
                    onTap: widget.onEditDistance,
                    tooltip: strings.timeForDistanceLabel(
                      widget.distanceMeters,
                    ),
                  ),
                ),
                DataColumn(label: Text(strings.speedKmh)),
              ],
              rows: widget.entries
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
