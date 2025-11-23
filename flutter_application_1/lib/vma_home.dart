import 'dart:ffi';

import 'package:flutter/material.dart';
import 'vma_distance_dialog.dart';
import 'vma_pace.dart';
import 'vma_settings_dialog.dart';
import 'vma_storage.dart';
import 'vma_table.dart';
import 'vma_times_settings_dialog.dart';
import 'vma_times_table.dart';
import 'distance_extensions.dart';

class VmaHomePage extends StatefulWidget {
  const VmaHomePage({super.key});

  @override
  State<VmaHomePage> createState() => _VmaHomePageState();
}

class _VmaHomePageState extends State<VmaHomePage> {
  final _vmaStorage = VmaStorage();
  final _paceCalculator = VmaPaceCalculator();
  int _tabIndex = 0;
  double? _vma;
  bool _loading = true;
  double _minPercent = 60;
  double _maxPercent = 120;
  double _step = 5;
  double _distanceMeters = 400;
  double _timesMinDistance = 100;
  double _timesMaxDistance = marathon.toDouble();

  @override
  void initState() {
    super.initState();
    _loadVma();
  }

  Future<void> _loadVma() async {
    final stored = await _vmaStorage.load();
    if (!mounted) return;

    setState(() {
      _vma = stored;
      _loading = false;
    });

    if (stored == null) {
      await _promptForVma();
    }
  }

  Future<void> _promptForVma() async {
    final selected = await _vmaStorage.promptForVma(
      context,
      initialValue: _vma,
    );

    if (selected != null && mounted) {
      setState(() => _vma = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _vma == null
                            ? 'No VMA saved yet'
                            : 'Your VMA: ${_vma!.toStringAsFixed(2)} km/h',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _promptForVma,
                      icon: const Icon(Icons.directions_run),
                      label: Text(_vma == null ? 'Set VMA' : 'Update VMA'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: _vma == null
                      ? const Center(
                          child: Text('Enter your VMA to see pace targets.'),
                        )
                      : _tabIndex == 0
                      ? VmaPaceTable(
                          entries: _paceCalculator.buildTable(
                            _vma!,
                            minPercent: _minPercent,
                            maxPercent: _maxPercent,
                            step: _step,
                            distanceMeters: _distanceMeters,
                          ),
                          onEditPercentages: _openTableSettingsDialog,
                          distanceMeters: _distanceMeters,
                          onEditDistance: _openDistanceDialog,
                        )
                      : VmaTimesTable(
                          vma: _vma!,
                          minDistanceMeters: _timesMinDistance,
                          maxDistanceMeters: _timesMaxDistance,
                          onEditDistances: _openTimesSettingsDialog,
                        ),
                ),
              ],
            ),
          );

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (idx) => setState(() => _tabIndex = idx),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Intensity',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.timer), label: 'Times'),
        ],
      ),
    );
  }

  Future<void> _openTableSettingsDialog() async {
    final result = await showVmaSettingsDialog(
      context,
      initialSettings: VmaTableSettings(
        minPercent: _minPercent,
        maxPercent: _maxPercent,
        step: _step,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _minPercent = result.minPercent;
        _maxPercent = result.maxPercent;
        _step = result.step;
      });
    }
  }

  Future<void> _openDistanceDialog() async {
    final updatedDistance = await showDistanceDialog(
      context,
      initialDistanceMeters: _distanceMeters,
    );

    if (updatedDistance != null && mounted) {
      setState(() {
        _distanceMeters = updatedDistance;
      });
    }
  }

  Future<void> _openTimesSettingsDialog() async {
    final result = await showTimesSettingsDialog(
      context,
      initialSettings: VmaTimesSettings(
        minDistance: _timesMinDistance,
        maxDistance: _timesMaxDistance,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _timesMinDistance = result.minDistance;
        _timesMaxDistance = result.maxDistance;
      });
    }
  }
}
