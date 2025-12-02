import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vma_running/train_data_loader.dart';
import 'app_localizations.dart';
import 'time_utils.dart';
import 'training_plan.dart';

class VmaTrainingPlan extends StatefulWidget {
  final double userVma;

  VmaTrainingPlan({super.key, required this.userVma});

  final AdvancedGitHubCacheManager cacheManager = AdvancedGitHubCacheManager();

  @override
  State<VmaTrainingPlan> createState() => _VmaTrainingPlanState();
}

class _VmaTrainingPlanState extends State<VmaTrainingPlan> {
  int _selectedGroup = 0;
  late final Future<TrainingPlan> _planFuture;

  @override
  void initState() {
    super.initState();
    // _planFuture = loadTrainingPlanFromAssets(
    //   'assets/training_plans/training_example.json',
    // );
    _planFuture = loadTraining();
  }

  // Load configuration with cache
  Future<TrainingPlan> loadTraining() async {
    const configUrl =
        "https://raw.githubusercontent.com/lougau92/vma-running/refs/heads/main/assets/training_plans/training_example.json";

    final result = await widget.cacheManager.getFile(configUrl);

    if (!result.fromCache) {
      print('Config loaded from network - fresh data');
    } else {
      print('Config loaded from cache (source: ${result.source})');
    }

    return TrainingPlan.fromJson(jsonDecode(result.data));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrainingPlan>(
      future: _planFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Error loading training plan: ${snapshot.error}'),
          );
        } else if (snapshot.hasData) {
          final plan = snapshot.data!;
          return _buildPlanContent(plan, context);
        } else {
          return Center(child: Text('No data available'));
        }
      },
    );
  }

  Widget _buildPlanContent(TrainingPlan plan, BuildContext context) {
    final group = plan.groups[_selectedGroup];
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
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
              ],
            ),
          ),
        ),
      ),
    );
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
              child: Text(_formatSet(set, strings)),
            ),
          ),
          if (block.afterRecoverySeconds != null) ...[
            const SizedBox(height: 4),
            Text(
              '${strings.recovery}: ${formatElapsed(block.afterRecoverySeconds!.toInt())} (${_recoveryLabel(block.afterRecoveryType, strings)})',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  String vmaToPace(double timesPercent) {
    final adjustedSpeed = vma * timesPercent / 100;
    final paceText = formatPacePerKm(adjustedSpeed, includeUnit: true);
    return paceText;
  }

  String _formatSet(IntervalSet set, AppLocalizations strings) {
    final reps = '${set.repetitions}x';
    final load = set.distanceMeters != null
        ? strings.distanceShort(set.distanceMeters!)
        : set.durationSeconds != null
        ? formatElapsed(set.durationSeconds!.toInt())
        : '';
    final pace = vmaToPace(set.vmaPercent);
    final recov =
        '${formatElapsed(set.recoverySeconds.toInt())} ${_recoveryLabel(set.recoveryType, strings)}';
    return '$reps $load @ $pace — $recov';
  }

  String _recoveryLabel(RecoveryType type, AppLocalizations strings) {
    switch (type) {
      case RecoveryType.active:
        return strings.activeRecovery;
      case RecoveryType.walk:
        return strings.walkRecovery;
      case RecoveryType.jog:
        return strings.jogRecovery;
      case RecoveryType.rest:
        return strings.restRecovery;
    }
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
