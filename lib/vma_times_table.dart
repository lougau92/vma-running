import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'interactive_header.dart';
import 'presets.dart';
import 'running/running.dart' show RunningSpeed, formatRunningDuration;

class VmaTimesTable extends StatefulWidget {
  const VmaTimesTable({
    super.key,
    required this.speed,
    required this.minDistanceMeters,
    required this.maxDistanceMeters,
    required this.minTimeSeconds,
    required this.maxTimeSeconds,
    required this.onEditDistances,
    required this.onEditTimes,
  });

  final RunningSpeed? speed;
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
    final colors = Theme.of(context).colorScheme;
    final data = _distanceFirst ? _buildDistances() : _buildTimes();

    final distanceHeader = SizedBox(
      width: 170,
      child: InteractiveHeader(
        label: strings.distance,
        icon: Icons.straighten,
        onTap: _distanceFirst ? widget.onEditDistances : null,
        tooltip: strings.distance,
        compact: true,
      ),
    );

    final timeHeader = SizedBox(
      width: 140,
      child: InteractiveHeader(
        label: strings.time,
        icon: Icons.schedule,
        onTap: !_distanceFirst ? widget.onEditTimes : null,
        tooltip: strings.time,
        compact: true,
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

    final distanceColumn = DataColumn(
      label: distanceHeader,
      headingRowAlignment: _distanceFirst
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
    );
    final timeColumn = DataColumn(
      label: timeHeader,
      headingRowAlignment: !_distanceFirst
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
    );

    final columns = [
      swapColumn,
      _distanceFirst ? distanceColumn : timeColumn,
      _distanceFirst ? timeColumn : distanceColumn,
    ];

    return FeedbackContextScope(
      id: 'times-table',
      data: {'mode': _distanceFirst ? 'distance-first' : 'time-first'},
      child: Scrollbar(
        thumbVisibility: true,
        controller: _verticalController,
        child: SingleChildScrollView(
          controller: _verticalController,
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320),
              child: DataTable(
                columnSpacing: 16,
                columns: columns,
                rows: [
                  for (var index = 0; index < data.length; index++)
                    DataRow(
                      color: WidgetStatePropertyAll(
                        index.isEven
                            ? colors.surface
                            : colors.surfaceContainerLow,
                      ),
                      cells: _buildRow(data[index], strings),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DataCell> _buildRow(double value, AppLocalizations strings) {
    final split = _distanceFirst
        ? widget.speed?.forDistance(value)
        : widget.speed?.forDuration(value);
    final meters = _distanceFirst ? value : split?.distanceMeters;
    final seconds = _distanceFirst ? split?.seconds : value;
    final distanceCell = DataCell(
      Align(
        alignment: _distanceFirst ? Alignment.center : Alignment.centerLeft,
        child: Text(meters == null ? '-' : strings.distanceShort(meters)),
      ),
    );
    final timeCell = DataCell(
      Align(
        alignment: !_distanceFirst ? Alignment.center : Alignment.centerLeft,
        child: Text(formatRunningDuration(seconds)),
      ),
    );
    const spacer = DataCell(SizedBox.shrink());
    return _distanceFirst
        ? [spacer, distanceCell, timeCell]
        : [spacer, timeCell, distanceCell];
  }

  List<double> _buildDistances() {
    return _filterRange(
      presetDistances(),
      widget.minDistanceMeters,
      widget.maxDistanceMeters,
    );
  }

  List<double> _buildTimes() {
    return _filterRange(
      presetTimesSeconds(),
      widget.minTimeSeconds,
      widget.maxTimeSeconds,
    );
  }

  List<double> _filterRange(List<double> values, double min, double max) {
    return values.where((value) => value >= min && value <= max).toList();
  }
}
