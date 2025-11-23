import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'app_settings.dart';
import 'distance_input.dart';
import 'vma_distance_dialog.dart';
import 'vma_pace.dart';
import 'vma_settings_dialog.dart';
import 'vma_storage.dart';
import 'vma_settings_page.dart';
import 'vma_table.dart';
import 'vma_times_settings_dialog.dart';
import 'vma_times_table.dart';

class VmaHomePage extends StatefulWidget {
  const VmaHomePage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

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
  double _timesMaxDistance = kMarathonMeters;

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
    final strings = AppLocalizations.of(context);
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
                            ? strings.noVma
                            : strings.yourVma(_vma!),
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _promptForVma,
                      icon: const Icon(Icons.directions_run),
                      label:
                          Text(_vma == null ? strings.setVma : strings.updateVma),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: _vma == null
                      ? Center(
                          child: Text(strings.enterVmaPlaceholder),
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
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: strings.settingsTab,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VmaSettingsPage(
                    settings: widget.settings,
                    onSettingsChanged: widget.onSettingsChanged,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (idx) => setState(() => _tabIndex = idx),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics),
            label: strings.intensityTab,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.timer),
            label: strings.timesTab,
          ),
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
