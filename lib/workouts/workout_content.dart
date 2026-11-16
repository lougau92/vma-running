import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'package:flutter/material.dart';
import '../app_localizations.dart';
import '../remote_asset_loader.dart';
import '../widgets/content_refresh_button.dart';
import 'workout.dart';
import 'workout_view.dart';
import 'workout_session_header.dart';

class WorkoutContent extends StatefulWidget {
  const WorkoutContent({
    super.key,
    required this.conversion,
    required this.result,
    required this.userVma,
    required this.onRefresh,
    required this.waiting,
  });
  final WorkoutConversion conversion;
  final RemoteLoadResult result;
  final double userVma;
  final Future<void> Function() onRefresh;
  final bool waiting;
  @override
  State<WorkoutContent> createState() => _WorkoutContentState();
}

class _WorkoutContentState extends State<WorkoutContent> {
  final _scroll = ScrollController();
  String? _sessionId, _versionLabel;
  int _versionIndex = 0;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    var sessionIndex = widget.conversion.workouts.indexWhere(
      (w) => w.id == _sessionId,
    );
    if (sessionIndex < 0) {
      sessionIndex = 0;
      _versionLabel = null;
    }
    final session = widget.conversion.workouts[sessionIndex];
    _sessionId = session.id;
    var versionIndex =
        _versionIndex < session.versions.length &&
            session.versions[_versionIndex].label == _versionLabel
        ? _versionIndex
        : session.versions.indexWhere((v) => v.label == _versionLabel);
    if (versionIndex < 0) versionIndex = 0;
    final version = session.versions[versionIndex];
    _versionLabel = version.label;
    _versionIndex = versionIndex;
    final path = '/workouts/$sessionIndex';
    final versionPath = '$path/versions/$versionIndex';
    final view = WorkoutNodeViewData(
      s,
      widget.userVma,
      widget.conversion.issues,
    );
    return FeedbackContextScope(
      id: 'workout-content',
      data: {
        'source': widget.result.origin.name,
        'refreshing': widget.result.refreshing,
      },
      child: FeedbackContextScope(
        id: 'workout',
        data: {
          'workoutId': session.id,
          'selectedVersion': version.label,
          'selectedGroup': versionIndex,
          'groupCount': session.versions.length,
        },
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.trainingPlanTab,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                            ContentRefreshButton(
                              refreshing:
                                  widget.result.refreshing || widget.waiting,
                              onRefresh: widget.onRefresh,
                            ),
                          ],
                        ),
                        if (widget.conversion.workouts.length > 1)
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'sessions-${widget.conversion.workouts.map((w) => w.id).join(',')}-${session.id}',
                            ),
                            initialValue: session.id,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: s['workout_session'],
                            ),
                            items: [
                              for (final workout in widget.conversion.workouts)
                                DropdownMenuItem(
                                  value: workout.id,
                                  child: Text(
                                    workout.title,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (id) => setState(() {
                              _sessionId = id;
                              _versionLabel = null;
                            }),
                          ),
                        const SizedBox(height: 12),
                        WorkoutSessionHeader(session: session),
                        const SizedBox(height: 8),
                        ...view.notes(widget.conversion.notes),
                        ...[
                          FeedbackContextScope(
                            id: 'notes',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: view.notes(session.notes),
                            ),
                          ),
                        ],
                        ...view.warnings(path),
                        ...view.globalWarnings(),
                        if (session.versions.length > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (
                                  var i = 0;
                                  i < session.versions.length;
                                  i++
                                )
                                  ChoiceChip(
                                    label: Text(session.versions[i].label),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    selectedColor: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    labelStyle: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          color: i == versionIndex
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onPrimaryContainer
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                        ),
                                    selected: i == versionIndex,
                                    onSelected: (_) => setState(() {
                                      _versionLabel = session.versions[i].label;
                                      _versionIndex = i;
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        if (version.audience != null) Text(version.audience!),
                        ...view.notes(version.notes),
                        ...view.warnings(versionPath),
                        const SizedBox(height: 12),
                        WorkoutPhaseCard(
                          title: s.preSession,
                          phase: version.warmup,
                          path: '$versionPath/warmup',
                          view: view,
                          kind: 0,
                        ),
                        WorkoutPhaseCard(
                          title: s.sessionContent,
                          phase: version.main,
                          path: '$versionPath/main',
                          view: view,
                          kind: 1,
                        ),
                        WorkoutPhaseCard(
                          title: s.cooldown,
                          phase: version.cooldown,
                          path: '$versionPath/cooldown',
                          view: view,
                          kind: 2,
                        ),
                        if (widget.conversion.issues.isNotEmpty)
                          ExpansionTile(
                            title: Text(s['workout_interpretations']),
                            children: [
                              for (final issue in widget.conversion.issues)
                                ListTile(
                                  title: Text(issue.message),
                                  subtitle: issue.resolution == null
                                      ? Text(s['workout_warning'])
                                      : Text(
                                          '${s['workout_resolved']}: ${issue.resolution} · ${s['workout_resolved_by_${issue.resolvedBy}']}',
                                        ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
