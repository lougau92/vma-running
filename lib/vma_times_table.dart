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
    this.customDistances = const [],
    this.customTimes = const [],
  });

  final RunningSpeed? speed;
  final double minDistanceMeters;
  final double maxDistanceMeters;
  final double minTimeSeconds;
  final double maxTimeSeconds;
  final VoidCallback onEditDistances;
  final VoidCallback onEditTimes;
  final List<double> customDistances;
  final List<double> customTimes;

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

    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final distanceWidth = 100.0 * textScale;
    final timeWidth = 140.0 * textScale;
    const margin = 12.0;
    const spacing = 32.0;
    const headingHeight = 72.0;
    final firstWidth = _distanceFirst ? distanceWidth : timeWidth;
    final tableWidth = distanceWidth + timeWidth + spacing + margin * 2;

    Widget header(String label, double width, VoidCallback? edit) => SizedBox(
      width: width,
      child: Center(
        child: InteractiveHeader(
          label: label,
          onTap: edit,
          tooltip: label,
          compact: true,
        ),
      ),
    );
    final distanceColumn = DataColumn(
      label: header(
        strings.distance,
        distanceWidth,
        _distanceFirst ? widget.onEditDistances : null,
      ),
      headingRowAlignment: MainAxisAlignment.center,
    );
    final timeColumn = DataColumn(
      label: header(
        strings.time,
        timeWidth,
        !_distanceFirst ? widget.onEditTimes : null,
      ),
      headingRowAlignment: MainAxisAlignment.center,
    );
    final table = SizedBox(
      width: tableWidth,
      child: Stack(
        children: [
          DataTable(
            columnSpacing: spacing,
            horizontalMargin: margin,
            headingRowHeight: headingHeight,
            columns: [
              _distanceFirst ? distanceColumn : timeColumn,
              _distanceFirst ? timeColumn : distanceColumn,
            ],
            rows: [
              for (var index = 0; index < data.length; index++)
                DataRow(
                  color: WidgetStatePropertyAll(
                    index.isEven ? colors.surface : colors.surfaceContainerLow,
                  ),
                  cells: _buildRow(
                    data[index],
                    strings,
                    distanceWidth,
                    timeWidth,
                  ),
                ),
            ],
          ),
          // The target straddles the heading boundary; it needs no empty column.
          Positioned(
            left: margin + firstWidth + spacing / 2 - 22,
            top: (headingHeight - 44) / 2,
            child: Material(
              color: colors.surface,
              shape: CircleBorder(
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: IconButton(
                key: const ValueKey('times-swap-columns'),
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () =>
                    setState(() => _distanceFirst = !_distanceFirst),
                icon: Icon(Icons.swap_horiz, color: colors.primary),
                tooltip: '${strings.distance} ⇄ ${strings.time}',
              ),
            ),
          ),
        ],
      ),
    );

    return FeedbackContextScope(
      id: 'times-table',
      data: {'mode': _distanceFirst ? 'distance-first' : 'time-first'},
      child: LayoutBuilder(
        builder: (context, constraints) => Scrollbar(
          thumbVisibility: true,
          controller: _verticalController,
          child: SingleChildScrollView(
            controller: _verticalController,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Align(alignment: Alignment.topCenter, child: table),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DataCell> _buildRow(
    double value,
    AppLocalizations strings,
    double distanceWidth,
    double timeWidth,
  ) {
    final split = _distanceFirst
        ? widget.speed?.forDistance(value)
        : widget.speed?.forDuration(value);
    final meters = _distanceFirst ? value : split?.distanceMeters;
    final seconds = _distanceFirst ? split?.seconds : value;
    final distanceCell = DataCell(
      SizedBox(
        width: distanceWidth,
        child: Center(
          child: Text(meters == null ? '-' : strings.distanceShort(meters)),
        ),
      ),
    );
    final timeCell = DataCell(
      SizedBox(
        width: timeWidth,
        child: Center(child: Text(formatRunningDuration(seconds))),
      ),
    );
    return _distanceFirst ? [distanceCell, timeCell] : [timeCell, distanceCell];
  }

  List<double> _buildDistances() {
    return _filterRange(
      mergePresetValues(presetDistances(), widget.customDistances),
      widget.minDistanceMeters,
      widget.maxDistanceMeters,
    );
  }

  List<double> _buildTimes() {
    return _filterRange(
      mergePresetValues(presetTimesSeconds(), widget.customTimes),
      widget.minTimeSeconds,
      widget.maxTimeSeconds,
    );
  }

  List<double> _filterRange(List<double> values, double min, double max) {
    return values.where((value) => value >= min && value <= max).toList();
  }
}
