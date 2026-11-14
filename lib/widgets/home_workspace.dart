import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../app_settings.dart';
import 'club_communications_page.dart';
import '../feature_flags.dart';
import '../remote_asset_loader.dart';
import 'challenge_table.dart';
import 'training_plan_page.dart';
import 'decorated_scaffold.dart';
import 'page_swipe_region.dart';
import 'running_calculator_tab.dart';
import 'intensity_tab.dart';
import 'times_tab.dart';

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

class HomeWorkspace extends StatefulWidget {
  const HomeWorkspace({
    super.key,
    required this.appBar,
    required this.loading,
    required this.vma,
    required this.settings,
    required this.onSettingsChanged,
    required this.features,
    required this.loader,
  });

  final PreferredSizeWidget appBar;
  final bool loading;
  final double? vma;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final FeatureFlags features;
  final RemoteAssetLoader loader;

  @override
  State<HomeWorkspace> createState() => _HomeWorkspaceState();
}

class _HomeWorkspaceState extends State<HomeWorkspace> {
  _HomePage _selectedPage = _HomePage.intensity;
  final _visitedPages = <_HomePage>{_HomePage.intensity};

  List<_HomePage> get _pages => [
    _HomePage.intensity,
    _HomePage.times,
    _HomePage.trainingPlan,
    _HomePage.calculator,
    if (widget.features.clubCommunications) _HomePage.communications,
    if (widget.features.clubRankings) _HomePage.rankings,
  ];

  @override
  void didUpdateWidget(covariant HomeWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_pages.contains(_selectedPage)) {
      _selectedPage = _HomePage.intensity;
    }
    _visitedPages.removeWhere((page) => !_pages.contains(page));
    _visitedPages.add(_selectedPage);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return DecoratedScaffold(
      appBar: widget.appBar,
      body: widget.loading
          ? const Center(child: CircularProgressIndicator())
          : _buildPageBody(strings),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark
            ? theme.colorScheme.secondary
            : theme.colorScheme.surface,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: isDark
            ? Colors.white70
            : theme.colorScheme.onSurface,
        currentIndex: _pages.indexOf(_selectedPage),
        onTap: (index) => _selectPage(_pages[index]),
        items: _navigationItems(strings),
      ),
    );
  }

  Widget _buildPageBody(AppLocalizations strings) {
    final pages = _pages;
    final pageIndex = pages.indexOf(_selectedPage);
    return PageSwipeRegion(
      pageIndex: pageIndex,
      allowTableEdgeSwipes: _isTablePage(_selectedPage),
      onSwipe: (direction) {
        final next = pages.indexOf(_selectedPage) + direction;
        if (next >= 0 && next < pages.length) _selectPage(pages[next]);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < pages.length; index++)
            if (_visitedPages.contains(pages[index]))
              Offstage(
                key: ValueKey(pages[index]),
                offstage: index != pageIndex,
                child: TickerMode(
                  enabled: index == pageIndex,
                  child: _buildPage(pages[index], strings),
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
    final vma = widget.vma;
    final Widget content;
    if (vma == null && page.requiresVma) {
      content = Center(child: Text(strings.enterVmaPlaceholder));
    } else {
      content = switch (page) {
        _HomePage.intensity => IntensityTab(vma: vma!),
        _HomePage.times => TimesTab(
          vma: vma!,
          settings: widget.settings,
          onSettingsChanged: widget.onSettingsChanged,
        ),
        _HomePage.trainingPlan => TrainingPlanPage(
          userVma: vma!,
          settings: widget.settings,
          onSettingsChanged: widget.onSettingsChanged,
          loader: widget.loader,
        ),
        _HomePage.calculator => RunningCalculatorTab(
          savedVma: vma,
          onNavigatePage: (direction) {
            if (_selectedPage != page) return;
            final nextIndex = _pages.indexOf(page) + direction;
            if (nextIndex >= 0 && nextIndex < _pages.length) {
              _selectPage(_pages[nextIndex]);
            }
          },
        ),
        _HomePage.communications => ClubCommunicationsPage(
          loader: widget.loader,
        ),
        _HomePage.rankings => ChallengeTable(loader: widget.loader),
      };
    }

    final ownsFeedbackContext =
        page == _HomePage.calculator ||
        (vma != null &&
            (page == _HomePage.intensity || page == _HomePage.times));
    final pageContent = ownsFeedbackContext
        ? content
        : FeedbackContextScope(
            id: page.contextId,
            isScreen: true,
            data: _pageContextState(page, vma),
            child: content,
          );
    return Padding(
      padding: EdgeInsets.fromLTRB(24, _isTablePage(page) ? 8 : 24, 24, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: pageContent,
        ),
      ),
    );
  }

  Map<String, Object?> _pageContextState(_HomePage page, double? vma) => {
    if (page.requiresVma && (page == _HomePage.trainingPlan || vma == null))
      'vmaKmh': vma,
  };

  bool _isTablePage(_HomePage page) =>
      page == _HomePage.intensity || page == _HomePage.times;

  List<BottomNavigationBarItem> _navigationItems(AppLocalizations strings) =>
      _pages.map((page) {
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
      }).toList();
}
