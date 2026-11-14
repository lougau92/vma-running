import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:vma_running/remote_asset_loader.dart';
import '../app_localizations.dart';
import '../content_refresh.dart' show refreshContent;
import 'content_refresh_button.dart' show ContentRefreshButton;
import '../app_settings.dart';
import '../plan_exporter.dart';
import '../running.dart';
import '../training_plan.dart';

class TrainingPlanResult {
  const TrainingPlanResult({
    required this.plan,
    this.noticeKey,
    this.refreshing = false,
    required this.origin,
  });

  final RemoteLoadOrigin origin;
  final TrainingPlan plan;
  final String? noticeKey;
  final bool refreshing;
}

class TrainingPlanPage extends StatefulWidget {
  final double userVma;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final RemoteAssetLoader loader;

  TrainingPlanPage({
    super.key,
    required this.userVma,
    required this.settings,
    required this.onSettingsChanged,
    RemoteAssetLoader? loader,
  }) : loader = loader ?? RemoteAssetLoader();

  @override
  State<TrainingPlanPage> createState() => _TrainingPlanPageState();
}

class _TrainingPlanPageState extends State<TrainingPlanPage> {
  static const _documentPath = 'app_documents/training_plan';
  static const _assetFallbackPath =
      'assets/training_plans/training_example.json';

  int _selectedGroup = 0;
  late Stream<TrainingPlanResult> _planStream;
  String? _lastNoticeKey;
  final List<PlanExporter> _exporters = [ClipboardPlanExporter()];
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _planStream = _watchText().map(_trainingResult);
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  Stream<RemoteLoadResult> _watchText() => widget.loader.watchText(
    documentPath: _documentPath,
    assetPath: _assetFallbackPath,
    validate: _parsePlan,
  );

  Future<void> _refreshPlan() => refreshContent(_watchText(), (stream) {
    setState(() {
      _lastNoticeKey = null;
      _planStream = stream.map(_trainingResult);
    });
  });

  TrainingPlan _parsePlan(String text) {
    final plan = TrainingPlan.fromJson(jsonDecode(text));
    if (plan.groups.isEmpty) throw const FormatException('Plan has no groups');
    return plan;
  }

  TrainingPlanResult _trainingResult(RemoteLoadResult result) {
    if (!result.refreshing) _logSource(result);
    return TrainingPlanResult(
      plan: _parsePlan(result.data),
      noticeKey: _noticeKeyForOrigin(result),
      refreshing: result.refreshing,
      origin: result.origin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TrainingPlanResult>(
      stream: _planStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error loading training plan: ${snapshot.error}'),
          );
        } else if (snapshot.hasData) {
          final result = snapshot.data!;
          _notifyIfNeeded(result.noticeKey);
          return FeedbackContextScope(
            id: 'workout-content',
            data: {
              'source': result.origin.name,
              'refreshing': result.refreshing,
            },
            child: _buildPlanContent(
              result.plan,
              context,
              refreshing:
                  snapshot.connectionState == ConnectionState.waiting ||
                  result.refreshing,
            ),
          );
        } else {
          return const Center(child: Text('No data available'));
        }
      },
    );
  }

  Widget _buildPlanContent(
    TrainingPlan plan,
    BuildContext context, {
    required bool refreshing,
  }) {
    final selectedGroup = _selectedGroup.clamp(0, plan.groups.length - 1);
    final group = plan.groups[selectedGroup];
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return FeedbackContextScope(
      id: 'workout',
      data: {
        'selectedGroup': selectedGroup,
        'groupCount': plan.groups.length,
        'refreshing': refreshing,
      },
      child: RefreshIndicator(
        onRefresh: _refreshPlan,
        child: Scrollbar(
          thumbVisibility: true,
          controller: _verticalController,
          child: SingleChildScrollView(
            controller: _verticalController,
            physics: const AlwaysScrollableScrollPhysics(),
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          strings.trainingPlanTab,
                          style: theme.textTheme.titleMedium,
                        ),
                        ContentRefreshButton(
                          refreshing: refreshing,
                          onRefresh: _refreshPlan,
                        ),
                        if (plan.groups.length > 1)
                          SegmentedButton<int>(
                            segments: [
                              for (var i = 0; i < plan.groups.length; i++)
                                ButtonSegment(
                                  value: i,
                                  label: Text(plan.groups[i].title),
                                ),
                            ],
                            selected: {selectedGroup},
                            showSelectedIcon: false,
                            onSelectionChanged: (selection) => setState(
                              () => _selectedGroup = selection.single,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _PlanCard(
                      contextId: 'warmup',
                      background: theme.colorScheme.tertiaryContainer,
                      foreground: theme.colorScheme.onTertiaryContainer,
                      title: strings.preSession,
                      children: _sectionLines([plan.warmup]),
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      contextId: 'intervals',
                      contextData: {'blockCount': group.blocks.length},
                      background: theme.colorScheme.primaryContainer,
                      foreground: theme.colorScheme.onPrimaryContainer,
                      title: strings.sessionContent,
                      children: [
                        for (final block in group.blocks)
                          _BlockView(
                            block: block,
                            strings: strings,
                            vma: widget.userVma,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      contextId: 'cooldown',
                      background: theme.colorScheme.secondaryContainer,
                      foreground: theme.colorScheme.onSecondaryContainer,
                      title: strings.cooldown,
                      children: _sectionLines([plan.cooldown]),
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      contextId: 'notes',
                      background: theme.colorScheme.surfaceContainerHigh,
                      foreground: theme.colorScheme.onSurface,
                      title: strings.remarks,
                      children: _sectionLines([plan.remarks]),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _exportPlan(plan),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(strings.export),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportPlan(TrainingPlan plan) async {
    if (_exporters.isEmpty || !mounted) return;
    final strings = AppLocalizations.of(context);
    final exporter = await _chooseExporter(strings);
    if (exporter == null || !mounted) return;

    final data = PlanExportData(
      plan: plan,
      group: plan.groups[_selectedGroup.clamp(0, plan.groups.length - 1)],
      userVma: widget.userVma,
      strings: strings,
    );

    await exporter.export(data, context);
  }

  Future<PlanExporter?> _chooseExporter(AppLocalizations strings) async {
    if (_exporters.length == 1) return _exporters.first;
    return showModalBottomSheet<PlanExporter>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _exporters
              .map(
                (exp) => ListTile(
                  leading: Icon(exp.icon),
                  title: Text(exp.label(strings)),
                  onTap: () => Navigator.of(ctx).pop(exp),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _notifyIfNeeded(String? noticeKey) {
    if (noticeKey == null || noticeKey == _lastNoticeKey || !mounted) return;
    _lastNoticeKey = noticeKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final strings = AppLocalizations.of(context);
      final message = strings[noticeKey];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _logSource(RemoteLoadResult result) {
    if (!kDebugMode) return;
    switch (result.origin) {
      case RemoteLoadOrigin.network:
        debugPrint('Plan loaded from Firestore');
        break;
      case RemoteLoadOrigin.cache:
        debugPrint('Plan loaded from local cache');
        break;
      case RemoteLoadOrigin.asset:
        debugPrint(
          'Failed to load remote training plan, falling back to asset',
        );
        break;
    }
  }

  String? _noticeKeyForOrigin(RemoteLoadResult result) {
    if (result.refreshing || result.error == null) return null;
    if (result.origin == RemoteLoadOrigin.cache) {
      return 'trainingPlanUsedCache';
    }
    if (result.origin == RemoteLoadOrigin.asset) {
      return 'trainingPlanUsedFallback';
    }
    return null;
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({
    required this.block,
    required this.strings,
    required this.vma,
  });

  final TrainingBlock block;
  final AppLocalizations strings;
  final double vma;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            block.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          ...block.sets.map(
            (set) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(formatSetLine(set, vma, strings)),
            ),
          ),
          if (block.afterRecoverySeconds != null) ...[
            const SizedBox(height: 4),
            Text(
              '${strings.recovery}: ${formatElapsed(block.afterRecoverySeconds!.toInt())} (${recoveryLabel(block.afterRecoveryType, strings)})',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.contextId,
    this.contextData = const {},
    required this.title,
    required this.children,
    required this.background,
    required this.foreground,
  });

  final String contextId;
  final Map<String, Object?> contextData;
  final String title;
  final List<Widget> children;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FeedbackContextScope(
      id: contextId,
      data: contextData,
      child: Card(
        color: background,
        surfaceTintColor: Colors.transparent,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<Widget> _sectionLines(Iterable<String> lines) => [
  for (final line in lines)
    Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line)),
];
