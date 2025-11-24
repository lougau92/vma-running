import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'app_settings.dart';
import 'decorated_scaffold.dart';
import 'distance_extensions.dart';
import 'presets.dart';
import 'theme.dart';
import 'time_utils.dart';
import 'training_plan.dart';
import 'vma_distance_dialog.dart';
import 'vma_pace.dart';
import 'vma_settings_dialog.dart';
import 'vma_storage.dart';
import 'vma_settings_page.dart';
import 'vma_table.dart';
import 'vma_times_settings_dialog.dart';
import 'vma_times_table.dart';
import 'vma_training_plan.dart';

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
  double _timesMinSeconds = presetTimesSeconds().first;
  double _timesMaxSeconds = presetTimesSeconds().last;
  double _timesPercent = 100;

  @override
  void initState() {
    super.initState();
    _timesMinDistance = widget.settings.timesMinDistance ?? _timesMinDistance;
    _timesMaxDistance = widget.settings.timesMaxDistance ?? _timesMaxDistance;
    _timesMinSeconds = widget.settings.timesMinSeconds ?? _timesMinSeconds;
    _timesMaxSeconds = widget.settings.timesMaxSeconds ?? _timesMaxSeconds;
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
            child: _vma == null
                ? Center(child: Text(strings.enterVmaPlaceholder))
                : _tabIndex == 0
                ? _buildPaceBody(strings)
                : _tabIndex == 1
                ? _buildTimesBody(strings)
                : VmaTrainingPlan(userVma: _vma!),
          );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedScaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/enjambee_img/logo-header-minimized.png',
              height: 32,
            ),
            const SizedBox(width: 8),
            Text(strings.appTitle),
          ],
        ),
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
        backgroundColor: isDark
            ? EnjambeeTheme.navy
            : Theme.of(context).colorScheme.surface,
        selectedItemColor: isDark
            ? EnjambeeTheme.orange
            : Theme.of(context).colorScheme.primary,
        unselectedItemColor: isDark
            ? Colors.white70
            : Theme.of(context).colorScheme.onSurface,
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
          BottomNavigationBarItem(
            icon: const Icon(Icons.fitness_center),
            label: strings.trainingPlanTab,
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

  Future<void> _openDistancesSettingDialog() async {
    final result = await showDistancesSettingsDialog(
      context,
      initialMin: _timesMinDistance,
      initialMax: _timesMaxDistance,
    );

    if (result != null && mounted) {
      setState(() {
        _timesMinDistance = result.min;
        _timesMaxDistance = result.max;
      });
    }
  }

  Future<void> _openTimesSettingsDialog() async {
    final result = await showTimesSettingsDialog(
      context,
      initialMinSeconds: _timesMinSeconds,
      initialMaxSeconds: _timesMaxSeconds,
    );

    if (result != null && mounted) {
      setState(() {
        _timesMinSeconds = result.minSeconds;
        _timesMaxSeconds = result.maxSeconds;
      });
    }
  }

  Widget _buildPaceBody(AppLocalizations strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVMAHeader(strings),
        const SizedBox(height: 32),
        Expanded(
          child: VmaPaceTable(
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
    );
  }

  Widget _buildTimesBody(AppLocalizations strings) {
    final adjustedSpeed = _vma! * _timesPercent / 100;
    final paceText = formatPacePerKm(adjustedSpeed, includeUnit: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildVMAHeader(strings),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${strings.intensity}: ${_timesPercent.toStringAsFixed(0)}%VMA',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${strings.pacePerKm}: $paceText',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Slider(
                  value: _timesPercent,
                  min: 50,
                  max: 120,
                  divisions: 14,
                  label: '${_timesPercent.toStringAsFixed(0)}%',
                  onChanged: (value) {
                    setState(() {
                      _timesPercent = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: VmaTimesTable(
            speedKmh: adjustedSpeed,
            minDistanceMeters: _timesMinDistance,
            maxDistanceMeters: _timesMaxDistance,
            minTimeSeconds: _timesMinSeconds,
            maxTimeSeconds: _timesMaxSeconds,
            onEditDistances: _openDistancesSettingDialog,
            onEditTimes: _openTimesSettingsDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildVMAHeader(AppLocalizations strings) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            _vma == null ? strings.noVma : strings.yourVma(_vma!),
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _promptForVma,
          icon: const Icon(Icons.directions_run),
          label: Text(_vma == null ? strings.setVma : strings.updateVma),
        ),
      ],
    );
  }
}
