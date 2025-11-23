import 'package:flutter/material.dart';
import 'vma_distance_dialog.dart';
import 'vma_pace.dart';
import 'vma_settings_dialog.dart';
import 'vma_storage.dart';
import 'vma_table.dart';

class VmaHomePage extends StatefulWidget {
  const VmaHomePage({super.key});

  @override
  State<VmaHomePage> createState() => _VmaHomePageState();
}

class _VmaHomePageState extends State<VmaHomePage> {
  final _vmaStorage = VmaStorage();
  final _paceCalculator = VmaPaceCalculator();
  double? _vma;
  bool _loading = true;
  double _minPercent = 60;
  double _maxPercent = 120;
  double _step = 5;
  double _distanceMeters = 400;

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
            padding: const EdgeInsets.all(24),
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
                      : VmaPaceTable(
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
                        ),
                ),
              ],
            ),
          );

    return Scaffold(
      // appBar: AppBar(title: const Text('VMA Training')),
      body: body,
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
}
