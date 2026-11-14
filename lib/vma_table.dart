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
  final _columnOrder = [0, 1, 2, 3];
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
    final labels = [
      strings.intensity,
      strings.pacePerKm,
      strings.timeForDistanceLabel(widget.distanceMeters),
      strings.speedKmh,
    ];

    Widget header(int column) {
      final onTap = switch (column) {
        0 => widget.onEditPercentages,
        2 => widget.onEditDistance,
        _ => null,
      };
      final label = InteractiveHeader(
        label: labels[column],
        onTap: onTap,
        emphasized: column == _columnOrder.first,
      );
      Widget feedback() => Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(labels[column]),
        ),
      );
      return DragTarget<int>(
        key: ValueKey('pace-column-$column'),
        onWillAcceptWithDetails: (details) => details.data != column,
        onAcceptWithDetails: (details) {
          setState(() {
            final target = _columnOrder.indexOf(column);
            _columnOrder.remove(details.data);
            _columnOrder.insert(target, details.data);
          });
        },
        builder: (context, candidates, rejected) => LongPressDraggable<int>(
          data: column,
          feedback: feedback(),
          childWhenDragging: Opacity(opacity: 0.3, child: label),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: candidates.isEmpty ? null : colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: label,
          ),
        ),
      );
    }

    DataTable table(List<int> columns) => DataTable(
      // Both halves share fixed row heights so horizontal scrolling cannot
      // separate a value from its pinned row.
      headingRowHeight: 72,
      dataRowMinHeight: 48,
      dataRowMaxHeight: 48,
      horizontalMargin: 16,
      columnSpacing: 24,
      columns: [
        for (final column in columns)
          DataColumn(
            label: header(column),
            headingRowAlignment: column == _columnOrder.first
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
          ),
      ],
      rows: [
        for (var index = 0; index < widget.entries.length; index++)
          DataRow(
            color: WidgetStatePropertyAll(
              index.isEven ? colors.surface : colors.surfaceContainerLow,
            ),
            cells: [
              for (final column in columns)
                DataCell(
                  Align(
                    alignment: column == _columnOrder.first
                        ? Alignment.center
                        : Alignment.centerLeft,
                    child: Text(switch (column) {
                      0 =>
                        '${widget.entries[index].percent.toStringAsFixed(0)}%',
                      1 => widget.entries[index].pacePerKm,
                      2 => widget.entries[index].timeForDistance,
                      _ => widget.entries[index].speedKmh.toStringAsFixed(2),
                    }),
                  ),
                ),
            ],
          ),
      ],
    );

    return Scrollbar(
      thumbVisibility: true,
      controller: _verticalController,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: BorderDirectional(
                  end: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: table([_columnOrder.first]),
            ),
            Flexible(
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.depth == 0,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: table(_columnOrder.sublist(1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
