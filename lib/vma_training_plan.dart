import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vma_running/remote_asset_loader.dart';
import 'app_localizations.dart';
import 'app_settings.dart';
import 'plan_exporter.dart';
import 'time_utils.dart';
import 'training_plan.dart';

class TrainingPlanResult {
  const TrainingPlanResult({required this.plan, this.noticeKey});

  final TrainingPlan plan;
  final String? noticeKey;
}

class VmaTrainingPlan extends StatefulWidget {
  final double userVma;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final RemoteAssetLoader loader;

  VmaTrainingPlan({
    super.key,
    required this.userVma,
    required this.settings,
    required this.onSettingsChanged,
    RemoteAssetLoader? loader,
  }) : loader = loader ?? RemoteAssetLoader();

  @override
  State<VmaTrainingPlan> createState() => _VmaTrainingPlanState();
}

class _VmaTrainingPlanState extends State<VmaTrainingPlan> {
  static const _configUrl =
      'https://raw.githubusercontent.com/lougau92/vma-running/refs/heads/main/assets/training_plans/training_example.json';
  static const _assetFallbackPath =
      'assets/training_plans/training_example.json';

  int _selectedGroup = 0;
  late Future<TrainingPlanResult> _planFuture;
  String? _lastNoticeKey;
  final List<PlanExporter> _exporters = [
    ClipboardPlanExporter(),
    GarminPlanExporter(),
  ];
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _planFuture = loadTraining();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  Future<void> _refreshPlan({bool forceRefresh = true}) async {
    final nextPlan = loadTraining(forceRefresh: forceRefresh);
    setState(() {
      _lastNoticeKey = null;
      _planFuture = nextPlan;
    });
    await nextPlan;
  }

  Future<TrainingPlanResult> loadTraining({bool forceRefresh = false}) async {
    final result = await widget.loader.loadText(
      remoteUrl: _configUrl,
      assetPath: _assetFallbackPath,
      forceRefresh: forceRefresh,
    );

    _logSource(result);
    return TrainingPlanResult(
      plan: TrainingPlan.fromJson(jsonDecode(result.data)),
      noticeKey: _noticeKeyForOrigin(result, forceRefresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrainingPlanResult>(
      future: _planFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error loading training plan: ${snapshot.error}'),
          );
        } else if (snapshot.hasData) {
          final result = snapshot.data!;
          _notifyIfNeeded(result.noticeKey);
          return _buildPlanContent(result.plan, context);
        } else {
          return const Center(child: Text('No data available'));
        }
      },
    );
  }

  Widget _buildPlanContent(TrainingPlan plan, BuildContext context) {
    final group = plan.groups[_selectedGroup];
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return RefreshIndicator(
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
                  Row(
                    children: [
                      Text(
                        strings.trainingPlanTab,
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      ToggleButtons(
                        isSelected: List.generate(
                          plan.groups.length,
                          (i) => i == _selectedGroup,
                        ),
                        onPressed: (index) =>
                            setState(() => _selectedGroup = index),
                        children: plan.groups
                            .map(
                              (g) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(g.title),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(title: strings.preSession, items: [plan.warmup]),
                  const SizedBox(height: 12),
                  _BlocksCard(
                    group: group,
                    strings: strings,
                    vma: widget.userVma,
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(title: strings.cooldown, items: [plan.cooldown]),
                  const SizedBox(height: 12),
                  _SectionCard(title: strings.remarks, items: [plan.remarks]),
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
    );
  }

  Future<void> _exportPlan(TrainingPlan plan) async {
    if (_exporters.isEmpty || !mounted) return;
    final strings = AppLocalizations.of(context);
    final exporter = await _chooseExporter(strings);
    if (exporter == null || !mounted) return;

    final data = PlanExportData(
      plan: plan,
      group: plan.groups[_selectedGroup],
      userVma: widget.userVma,
      strings: strings,
      settings: widget.settings,
      onSettingsChanged: widget.onSettingsChanged,
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
      if (message == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _logSource(RemoteLoadResult result) {
    switch (result.origin) {
      case RemoteLoadOrigin.network:
        print('Plan loaded from network - fresh data');
        break;
      case RemoteLoadOrigin.cache:
        print('Plan loaded from cache (source: ${result.source})');
        break;
      case RemoteLoadOrigin.asset:
        print('Failed to load remote training plan, falling back to asset');
        break;
    }
  }

  String? _noticeKeyForOrigin(RemoteLoadResult result, bool forceRefresh) {
    if (result.origin == RemoteLoadOrigin.cache && forceRefresh) {
      return 'trainingPlanUsedCache';
    }
    if (result.origin == RemoteLoadOrigin.asset) {
      return 'trainingPlanUsedFallback';
    }
    return null;
  }
}

class _BlocksCard extends StatelessWidget {
  const _BlocksCard({
    required this.group,
    required this.strings,
    required this.vma,
  });

  final BlockGroup group;
  final AppLocalizations strings;
  final double vma;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.sessionContent, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...group.blocks.map(
              (block) => _BlockView(block: block, strings: strings, vma: vma),
            ),
          ],
        ),
      ),
    );
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
          Text(block.title, style: theme.textTheme.titleMedium),
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
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...items.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
