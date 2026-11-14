import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'package:flutter/material.dart';

import '../vma_distance_dialog.dart';
import '../vma_pace.dart';
import '../vma_settings_dialog.dart';
import '../vma_table.dart';
import 'centered_width.dart';

class VmaIntensityTab extends StatefulWidget {
  const VmaIntensityTab({super.key, required this.vma});

  final double vma;

  @override
  State<VmaIntensityTab> createState() => _VmaIntensityTabState();
}

class _VmaIntensityTabState extends State<VmaIntensityTab> {
  final _paceCalculator = VmaPaceCalculator();
  double _minPercent = 60;
  double _maxPercent = 120;
  double _step = 5;
  double _distanceMeters = 400;

  Future<void> _editPercentages() async {
    await showVmaSettingsDialog(
      context,
      initialSettings: VmaTableSettings(
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
      child: VmaPaceTable(
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
