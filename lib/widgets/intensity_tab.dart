import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'package:flutter/material.dart';

import 'distance_dialog.dart';
import '../pace.dart';
import 'pace_table_settings_dialog.dart';
import 'pace_table.dart';
import 'centered_width.dart';

class IntensityTab extends StatefulWidget {
  const IntensityTab({super.key, required this.vma});

  final double vma;

  @override
  State<IntensityTab> createState() => _IntensityTabState();
}

class _IntensityTabState extends State<IntensityTab> {
  final _paceCalculator = PaceCalculator();
  double _minPercent = 60;
  double _maxPercent = 120;
  double _step = 5;
  double _distanceMeters = 400;

  Future<void> _editPercentages() async {
    await showTableSettingsDialog(
      context,
      initialSettings: TableSettings(
        minPercent: _minPercent,
        maxPercent: _maxPercent,
        step: _step,
      ),
      onChanged: (settings) {
        if (!mounted) return;
        setState(() {
          _minPercent = settings.minPercent;
          _maxPercent = settings.maxPercent;
          _step = settings.step;
        });
      },
    );
  }

  Future<void> _editDistance() async {
    await showDistanceDialog(
      context,
      initialDistanceMeters: _distanceMeters,
      onChanged: (value) {
        if (mounted) setState(() => _distanceMeters = value);
      },
    );
  }

  @override
  Widget build(BuildContext context) => FeedbackContextScope(
    id: 'intensity',
    isScreen: true,
    data: {
      'vmaKmh': widget.vma,
      'minPercent': _minPercent,
      'maxPercent': _maxPercent,
      'stepPercent': _step,
      'distanceMeters': _distanceMeters,
    },
    child: CenteredWidth(
      child: PaceTable(
        entries: _paceCalculator.buildTable(
          widget.vma,
          minPercent: _minPercent,
          maxPercent: _maxPercent,
          step: _step,
          distanceMeters: _distanceMeters,
        ),
        onEditPercentages: _editPercentages,
        distanceMeters: _distanceMeters,
        onEditDistance: _editDistance,
      ),
    ),
  );
}
