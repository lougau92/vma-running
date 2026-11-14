import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'package:flutter/material.dart';

import '../app_settings.dart';
import '../presets.dart';
import '../running.dart' show RunningSpeed, kMarathonMeters;
import 'times_settings_dialog.dart';
import 'times_table.dart';
import 'centered_width.dart';
import 'intensity_pace_control.dart';

class TimesTab extends StatefulWidget {
  const TimesTab({
    super.key,
    required this.vma,
    required this.settings,
    required this.onSettingsChanged,
  });

  final double vma;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<TimesTab> createState() => _TimesTabState();
}

class _TimesTabState extends State<TimesTab> {
  double _percent = 100;
  double _minDistance = 100;
  double _maxDistance = kMarathonMeters;
  double _minSeconds = presetTimesSeconds().first;
  double _maxSeconds = presetTimesSeconds().last;
  late List<double> _customDistances;
  late List<double> _customSeconds;

  @override
  void initState() {
    super.initState();
    _minDistance = widget.settings.timesMinDistance ?? _minDistance;
    _maxDistance = widget.settings.timesMaxDistance ?? _maxDistance;
    _minSeconds = widget.settings.timesMinSeconds ?? presetTimesSeconds().first;
    _maxSeconds = widget.settings.timesMaxSeconds ?? presetTimesSeconds().last;
    _customDistances = mergePresetValues(
      const [],
      widget.settings.timesCustomDistances,
    );
    _customSeconds = mergePresetValues(
      const [],
      widget.settings.timesCustomSeconds,
    );
  }

  Future<void> _editDistances() async {
    await showDistancesSettingsDialog(
      context,
      initialMin: _minDistance,
      initialMax: _maxDistance,
      customValues: _customDistances,
      onCustomValueAdded: (value) => _rememberCustomRow(value, distance: true),
      onResetCustomValues: () => _resetCustomRows(distance: true),
      onChanged: (range) {
        if (!mounted) return;
        setState(() {
          _minDistance = range.min;
          _maxDistance = range.max;
        });
      },
    );
    if (mounted) _persistSettings();
  }

  Future<void> _editTimes() async {
    await showTimesSettingsDialog(
      context,
      initialMinSeconds: _minSeconds,
      initialMaxSeconds: _maxSeconds,
      customValues: _customSeconds,
      onCustomValueAdded: (value) => _rememberCustomRow(value, distance: false),
      onResetCustomValues: () => _resetCustomRows(distance: false),
      onChanged: (range) {
        if (!mounted) return;
        setState(() {
          _minSeconds = range.minSeconds;
          _maxSeconds = range.maxSeconds;
        });
      },
    );
    if (mounted) _persistSettings();
  }

  void _rememberCustomRow(double value, {required bool distance}) {
    if (!mounted) return;
    final presets = distance ? presetDistances() : presetTimesSeconds();
    final current = distance ? _customDistances : _customSeconds;
    if (presets.contains(value) || current.contains(value)) return;
    setState(() {
      final next = mergePresetValues(current, [value]);
      if (distance) {
        _customDistances = next;
      } else {
        _customSeconds = next;
      }
    });
    _persistSettings();
  }

  void _resetCustomRows({required bool distance}) {
    if (!mounted) return;
    setState(() {
      if (distance) {
        _customDistances = [];
      } else {
        _customSeconds = [];
      }
    });
    _persistSettings();
  }

  void _persistSettings() => widget.onSettingsChanged(
    widget.settings.copyWith(
      timesMinDistance: _minDistance,
      timesMaxDistance: _maxDistance,
      timesMinSeconds: _minSeconds,
      timesMaxSeconds: _maxSeconds,
      timesCustomDistances: _customDistances,
      timesCustomSeconds: _customSeconds,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final speed = RunningSpeed.fromVma(widget.vma, _percent);
    return FeedbackContextScope(
      id: 'times',
      isScreen: true,
      data: {
        'vmaKmh': widget.vma,
        'intensityPercent': _percent,
        'minDistanceMeters': _minDistance,
        'maxDistanceMeters': _maxDistance,
        'minSeconds': _minSeconds,
        'maxSeconds': _maxSeconds,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CenteredWidth(
            child: IntensityPaceControl(
              percent: _percent,
              speed: speed,
              onChanged: (value) => setState(() => _percent = value),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CenteredWidth(
              child: TimesTable(
                speed: speed,
                minDistanceMeters: _minDistance,
                maxDistanceMeters: _maxDistance,
                minTimeSeconds: _minSeconds,
                maxTimeSeconds: _maxSeconds,
                customDistances: _customDistances,
                customTimes: _customSeconds,
                onEditDistances: _editDistances,
                onEditTimes: _editTimes,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
