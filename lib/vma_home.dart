import 'package:app_feedback/app_feedback.dart'
    show
        FeedbackButton,
        FeedbackSender,
        UnavailableFeedbackSender,
        FeedbackContextScope;
import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'app_settings.dart';
import 'feature_flags.dart';
import 'decorated_scaffold.dart';
import 'distance_extensions.dart';
import 'presets.dart';
import 'time_utils.dart';
import 'vma_distance_dialog.dart';
import 'vma_pace.dart';
import 'club_communications_page.dart';
import 'vma_settings_dialog.dart';
import 'remote_asset_loader.dart';
import 'vma_storage.dart';
import 'vma_settings_page.dart';
import 'vma_table.dart';
import 'vma_times_settings_dialog.dart';
import 'vma_times_table.dart';
import 'vma_challenge_table.dart';
import 'vma_training_plan.dart';

enum _HomePage {
  intensity('intensity'),
  times('times'),
  trainingPlan('training-plan'),
  communications('club-communications'),
  rankings('club-rankings');

  const _HomePage(this.contextId);
  final String contextId;

  bool get requiresVma => switch (this) {
    intensity || times || trainingPlan => true,
    communications || rankings => false,
  };
}

class VmaHomePage extends StatefulWidget {
  const VmaHomePage({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.feedbackSender = const UnavailableFeedbackSender(),
    this.features = const FeatureFlags(),
    this.loader,
  });

  final FeedbackSender feedbackSender;
  final FeatureFlags features;
  final RemoteAssetLoader? loader;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;

  @override
  State<VmaHomePage> createState() => _VmaHomePageState();
}

class _VmaHomePageState extends State<VmaHomePage> {
  final _vmaStorage = VmaStorage();
  final _paceCalculator = VmaPaceCalculator();
  late final RemoteAssetLoader _remoteLoader;
  _HomePage _selectedPage = _HomePage.intensity;

  List<_HomePage> get _pages => [
    _HomePage.intensity,
    _HomePage.times,
    _HomePage.trainingPlan,
    if (widget.features.clubCommunications) _HomePage.communications,
    if (widget.features.clubRankings) _HomePage.rankings,
  ];

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
  void didUpdateWidget(covariant VmaHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pages.contains(_selectedPage)) {
      _selectedPage = _HomePage.intensity;
    }
  }

  @override
  void initState() {
    super.initState();
    _remoteLoader = widget.loader ?? RemoteAssetLoader();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FeedbackContextScope(
      id: 'home',
      child: DecoratedScaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset(
                'assets/enjambee_img/logo-header-minimized.png',
                height: 32,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(strings.appTitle, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          actions: [
            FeedbackButton(sender: widget.feedbackSender),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: strings.settingsTab,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/settings'),
                    builder: (_) => VmaSettingsPage(
                      feedbackSender: widget.feedbackSender,
                      settings: widget.settings,
                      onSettingsChanged: widget.onSettingsChanged,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: _buildPageBody(strings),
        bottomNavigationBar: _buildBottomNavigation(strings, isDark),
      ),
    );
  }

  Widget _buildPageBody(AppLocalizations strings) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vma == null && _selectedPage.requiresVma) {
      return Center(child: Text(strings.enterVmaPlaceholder));
    }

    final content = switch (_selectedPage) {
      _HomePage.intensity => _buildPaceBody(strings),
      _HomePage.times => _buildTimesBody(strings),
      _HomePage.trainingPlan => VmaTrainingPlan(
        userVma: _vma!,
        settings: widget.settings,
        onSettingsChanged: widget.onSettingsChanged,
        loader: _remoteLoader,
      ),
      _HomePage.communications => ClubCommunicationsPage(loader: _remoteLoader),
      _HomePage.rankings => _buildChallengeBody(),
    };

    final hasVmaHeader =
        _selectedPage == _HomePage.intensity ||
        _selectedPage == _HomePage.times;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, hasVmaHeader ? 8 : 24, 24, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FeedbackContextScope(
            id: _selectedPage.contextId,
            isScreen: true,
            data: _pageContextState,
            child: content,
          ),
        ),
      ),
    );
  }

  Map<String, Object?> get _pageContextState => {
    if (_selectedPage.requiresVma) 'vmaKmh': _vma,
    if (_selectedPage == _HomePage.intensity) ...{
      'minPercent': _minPercent,
      'maxPercent': _maxPercent,
      'stepPercent': _step,
      'distanceMeters': _distanceMeters,
    },
    if (_selectedPage == _HomePage.times) ...{
      'intensityPercent': _timesPercent,
      'minDistanceMeters': _timesMinDistance,
      'maxDistanceMeters': _timesMaxDistance,
      'minSeconds': _timesMinSeconds,
      'maxSeconds': _timesMaxSeconds,
    },
  };

  BottomNavigationBar _buildBottomNavigation(
    AppLocalizations strings,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return BottomNavigationBar(
      backgroundColor: isDark
          ? theme.colorScheme.secondary
          : theme.colorScheme.surface,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: isDark
          ? Colors.white70
          : theme.colorScheme.onSurface,
      currentIndex: _pages.indexOf(_selectedPage),
      onTap: (idx) => setState(() => _selectedPage = _pages[idx]),
      items: _pages.map((page) {
        final (icon, label) = switch (page) {
          _HomePage.intensity => (Icons.analytics, strings.intensityTab),
          _HomePage.times => (Icons.timer, strings.timesTab),
          _HomePage.trainingPlan => (
            Icons.fitness_center,
            strings.trainingPlanTab,
          ),
          _HomePage.communications => (
            Icons.campaign_outlined,
            strings.communicationsTab,
          ),
          _HomePage.rankings => (Icons.emoji_events, strings.challengeTab),
        };
        return BottomNavigationBarItem(icon: Icon(icon), label: label);
      }).toList(),
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

  Widget _buildChallengeBody() {
    return _wrapCenteredWidth(VmaChallengeTable(loader: _remoteLoader));
  }

  Widget _buildPaceBody(AppLocalizations strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildVMAHeader(strings),
        const SizedBox(height: 8),
        Expanded(
          child: _wrapCenteredWidth(
            VmaPaceTable(
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
        ),
      ],
    );
  }

  Widget _buildTimesBody(AppLocalizations strings) {
    final adjustedSpeed = _vma! * _timesPercent / 100;
    final paceText = formatPacePerKm(adjustedSpeed, includeUnit: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildVMAHeader(strings),
        const SizedBox(height: 8),
        _wrapCenteredWidth(
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${strings.intensity}: ${_timesPercent.toStringAsFixed(0)}%VMA',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
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
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _wrapCenteredWidth(
            VmaTimesTable(
              speedKmh: adjustedSpeed,
              minDistanceMeters: _timesMinDistance,
              maxDistanceMeters: _timesMaxDistance,
              minTimeSeconds: _timesMinSeconds,
              maxTimeSeconds: _timesMaxSeconds,
              onEditDistances: _openDistancesSettingDialog,
              onEditTimes: _openTimesSettingsDialog,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVMAHeader(AppLocalizations strings) {
    return Tooltip(
      message: strings.updateVma,
      child: TextButton.icon(
        key: const ValueKey('vma-edit'),
        onPressed: _promptForVma,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: Theme.of(context).textTheme.titleSmall,
        ),
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(strings.yourVma(_vma!)),
      ),
    );
  }

  Widget _wrapCenteredWidth(Widget child, {double maxWidth = 900}) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
