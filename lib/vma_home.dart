import 'package:app_feedback/app_feedback.dart'
    show
        FeedbackButton,
        FeedbackSender,
        UnavailableFeedbackSender,
        FeedbackContextScope;
import 'package:flutter/material.dart';
import 'app_localizations.dart';
import 'app_settings.dart';
import 'calculator/running_calculator_draft.dart' show RunningCalculatorDraft;
import 'calculator/running_calculator_page.dart' show RunningCalculatorPage;
import 'feature_flags.dart';
import 'decorated_scaffold.dart';
import 'presets.dart';
import 'running/running.dart';
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
import 'widgets/vma_celebration_overlay.dart';
import 'widgets/page_swipe_region.dart';
import 'widgets/intensity_pace_control.dart';

enum _HomePage {
  intensity('intensity'),
  times('times'),
  trainingPlan('training-plan'),
  calculator('calculator'),
  communications('club-communications'),
  rankings('club-rankings');

  const _HomePage(this.contextId);
  final String contextId;

  bool get requiresVma => switch (this) {
    intensity || times || trainingPlan => true,
    calculator || communications || rankings => false,
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
  final _visitedPages = <_HomePage>{_HomePage.intensity};
  OverlayEntry? _celebrationEntry;

  List<_HomePage> get _pages => [
    _HomePage.intensity,
    _HomePage.times,
    _HomePage.trainingPlan,
    _HomePage.calculator,
    if (widget.features.clubCommunications) _HomePage.communications,
    if (widget.features.clubRankings) _HomePage.rankings,
  ];

  RunningCalculatorDraft _calculatorDraft = const RunningCalculatorDraft();
  double? _vma;
  double? _calculatorVma;
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
  void dispose() {
    _celebrationEntry?.remove();
    super.dispose();
  }

  void _setVma(double value) {
    final changed = _vma != null && value != _vma;
    setState(() {
      if (_vma != value) _calculatorVma = value;
      _vma = value;
    });
    if (changed) _celebrateVmaChange();
  }

  void _celebrateVmaChange() {
    _celebrationEntry?.remove();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: VmaCelebrationOverlay(
          onComplete: () {
            if (identical(_celebrationEntry, entry)) {
              entry.remove();
              _celebrationEntry = null;
            }
          },
        ),
      ),
    );
    _celebrationEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  @override
  void didUpdateWidget(covariant VmaHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pages.contains(_selectedPage)) {
      _selectedPage = _HomePage.intensity;
    }
    _visitedPages.removeWhere((page) => !_pages.contains(page));
    _visitedPages.add(_selectedPage);
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
      _calculatorVma = stored;
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

    if (selected != null && mounted) _setVma(selected);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FeedbackContextScope(
      id: 'home',
      child: DecoratedScaffold(
        appBar: AppBar(
          title: Image.asset(
            'assets/enjambee_img/logo-header-minimized.png',
            height: 32,
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
                      onVmaChanged: _setVma,
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

    final pages = _pages;
    return PageSwipeRegion(
      pageIndex: pages.indexOf(_selectedPage),
      allowTableEdgeSwipes:
          _selectedPage == _HomePage.intensity ||
          _selectedPage == _HomePage.times,
      onSwipe: (direction) {
        final next = pages.indexOf(_selectedPage) + direction;
        if (next >= 0 && next < pages.length) _selectPage(pages[next]);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final page in pages)
            if (_visitedPages.contains(page))
              Offstage(
                key: ValueKey(page),
                offstage: page != _selectedPage,
                child: TickerMode(
                  enabled: page == _selectedPage,
                  child: _buildPage(page, strings),
                ),
              ),
        ],
      ),
    );
  }

  void _selectPage(_HomePage page) {
    if (page == _selectedPage) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _visitedPages.add(page);
      _selectedPage = page;
    });
  }

  Widget _buildPage(_HomePage page, AppLocalizations strings) {
    final Widget content;
    if (_vma == null && page.requiresVma) {
      content = Center(child: Text(strings.enterVmaPlaceholder));
    } else {
      content = switch (page) {
        _HomePage.intensity => _buildPaceBody(),
        _HomePage.times => _buildTimesBody(),
        _HomePage.trainingPlan => VmaTrainingPlan(
          userVma: _vma!,
          settings: widget.settings,
          onSettingsChanged: widget.onSettingsChanged,
          loader: _remoteLoader,
        ),
        _HomePage.calculator => RunningCalculatorPage(
          draft: _calculatorDraft,
          vma: _calculatorVma,
          onVmaChanged: (value) => setState(() => _calculatorVma = value),
          onChanged: (draft) => setState(() => _calculatorDraft = draft),
        ),
        _HomePage.communications => ClubCommunicationsPage(
          loader: _remoteLoader,
        ),
        _HomePage.rankings => _buildChallengeBody(),
      };
    }

    final isTablePage = page == _HomePage.intensity || page == _HomePage.times;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, isTablePage ? 8 : 24, 24, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FeedbackContextScope(
            id: page.contextId,
            isScreen: true,
            data: _pageContextState(page),
            child: content,
          ),
        ),
      ),
    );
  }

  Map<String, Object?> _pageContextState(_HomePage page) => {
    if (page.requiresVma) 'vmaKmh': _vma,
    if (page == _HomePage.calculator) ...{
      'vmaKmh': _calculatorVma,
      'savedVmaKmh': _vma,
      'measures': [
        for (var index = 0; index < 4; index++)
          _calculatorDraft.measureAt(index).name,
      ],
      'inputIndices': _calculatorDraft.inputIndices,
    },
    if (page == _HomePage.intensity) ...{
      'minPercent': _minPercent,
      'maxPercent': _maxPercent,
      'stepPercent': _step,
      'distanceMeters': _distanceMeters,
    },
    if (page == _HomePage.times) ...{
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
      type: BottomNavigationBarType.fixed,
      backgroundColor: isDark
          ? theme.colorScheme.secondary
          : theme.colorScheme.surface,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: isDark
          ? Colors.white70
          : theme.colorScheme.onSurface,
      currentIndex: _pages.indexOf(_selectedPage),
      onTap: (idx) => _selectPage(_pages[idx]),
      items: _pages.map((page) {
        final (icon, label) = switch (page) {
          _HomePage.intensity => (Icons.analytics, strings.intensityTab),
          _HomePage.times => (Icons.timer, strings.timesTab),
          _HomePage.trainingPlan => (
            Icons.fitness_center,
            strings.trainingPlanTab,
          ),
          _HomePage.calculator => (
            Icons.calculate_outlined,
            strings['calculatorTab'],
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

  Future<void> _openDistanceDialog() async {
    await showDistanceDialog(
      context,
      initialDistanceMeters: _distanceMeters,
      onChanged: (value) {
        if (mounted) setState(() => _distanceMeters = value);
      },
    );
  }

  Future<void> _openDistancesSettingDialog() async {
    await showDistancesSettingsDialog(
      context,
      initialMin: _timesMinDistance,
      initialMax: _timesMaxDistance,
      onChanged: (range) {
        if (!mounted) return;
        setState(() {
          _timesMinDistance = range.min;
          _timesMaxDistance = range.max;
        });
      },
    );
  }

  Future<void> _openTimesSettingsDialog() async {
    await showTimesSettingsDialog(
      context,
      initialMinSeconds: _timesMinSeconds,
      initialMaxSeconds: _timesMaxSeconds,
      onChanged: (range) {
        if (!mounted) return;
        setState(() {
          _timesMinSeconds = range.minSeconds;
          _timesMaxSeconds = range.maxSeconds;
        });
      },
    );
  }

  Widget _buildChallengeBody() {
    return _wrapCenteredWidth(VmaChallengeTable(loader: _remoteLoader));
  }

  Widget _buildPaceBody() {
    return _wrapCenteredWidth(
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
    );
  }

  Widget _buildTimesBody() {
    final speed = RunningSpeed.fromVma(_vma, _timesPercent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _wrapCenteredWidth(
          IntensityPaceControl(
            percent: _timesPercent,
            speed: speed,
            onChanged: (value) => setState(() => _timesPercent = value),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _wrapCenteredWidth(
            VmaTimesTable(
              speed: speed,
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
