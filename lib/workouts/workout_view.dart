import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'package:flutter/material.dart';
import '../app_localizations.dart';
import 'workout.dart';
import 'workout_format.dart';

class WorkoutPhaseCard extends StatelessWidget {
  const WorkoutPhaseCard({
    super.key,
    required this.title,
    required this.phase,
    required this.path,
    required this.view,
    required this.kind,
  });
  final String title, path;
  final WorkoutPhase phase;
  final WorkoutNodeViewData view;
  final int kind;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return FeedbackContextScope(
      id: ['warmup', 'intervals', 'cooldown'][kind],
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: kind == 1
                  ? colors.primaryContainer
                  : colors.surfaceContainerLow,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                    child: Text(
                      (kind + 1).toString(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: kind == 1
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    [
                      Icons.wb_sunny_outlined,
                      Icons.directions_run_rounded,
                      Icons.spa_outlined,
                    ][kind],
                    color: kind == 1
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...view.warnings(path),
                  if (phase.plan != null)
                    WorkoutNodeView(
                      node: phase.plan!,
                      path: '$path/plan',
                      view: view,
                    )
                  else
                    Text(
                      view.s[phase.status == 'explicitly_none'
                          ? 'workout_phase_none'
                          : 'workout_phase_unspecified'],
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WorkoutNodeViewData {
  const WorkoutNodeViewData(this.s, this.vma, this.issues);
  final AppLocalizations s;
  final double vma;
  final List<WorkoutIssue> issues;
  List<Widget> notes(List<WorkoutNote> notes) => [
    for (final note in notes)
      Padding(padding: const EdgeInsets.only(top: 6), child: Text(note.text)),
  ];

  List<Widget> warnings(String path, {bool leaf = false}) {
    bool applies(String pointer) {
      if (pointer == path) return true;
      if (!pointer.startsWith('$path/')) return false;
      final field = pointer.substring(path.length + 1).split('/').first;
      return leaf ||
          const [
            'label',
            'optional',
            'notes',
            'count',
            'declaredDurationSeconds',
            'reason',
            'status',
            'audience',
            'title',
            'sport',
            'scheduledDate',
            'location',
          ].contains(field);
    }

    return [
      for (final issue in issues.where(
        (i) =>
            i.severity == 'warning' &&
            i.resolution == null &&
            i.paths.any(applies),
      ))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('${s['workout_warning']}: ${issue.message}'),
        ),
    ];
  }

  List<Widget> globalWarnings() => [
    for (final issue in issues.where(
      (i) =>
          i.severity == 'warning' &&
          i.resolution == null &&
          !i.paths.any((p) => p.startsWith('/workouts/')),
    ))
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('${s['workout_warning']}: ${issue.message}'),
      ),
  ];
}

class WorkoutNodeView extends StatelessWidget {
  const WorkoutNodeView({
    super.key,
    required this.node,
    required this.path,
    required this.view,
    this.between = false,
  });
  final WorkoutNode node;
  final String path;
  final WorkoutNodeViewData view;
  final bool between;

  @override
  Widget build(BuildContext context) {
    final s = view.s;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final children = <Widget>[];
    void line(String text, {bool strong = false}) => children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          text,
          style: strong
              ? theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )
              : theme.textTheme.bodyMedium,
        ),
      ),
    );
    if (node.optional) line(s['workout_optional'], strong: true);
    if (between) line(s['workout_between'], strong: true);
    switch (node) {
      case WorkoutStep step:
        final end = formatWorkoutEnd(step.end, s);
        final role = s['workout_role_${step.role}'];
        final label = step.label;
        children.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 10),
                child: Icon(
                  step.role == 'recovery'
                      ? Icons.pause_circle_outline_rounded
                      : Icons.directions_run_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      end,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (label != null &&
                        label.toLowerCase() != end.toLowerCase() &&
                        label.toLowerCase() != role.toLowerCase())
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(label),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (step.targets.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final target in step.targets)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        formatWorkoutTarget(target, s, view.vma),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
        if (step.role == 'recovery' || step.movement != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                formatWorkoutMovement(step.movement, s),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
      case WorkoutSequence sequence:
        if (sequence.label != null) line(sequence.label!, strong: true);
        if (sequence.declaredDuration != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${s['workout_budget']}: ${workoutRange(sequence.declaredDuration!, workoutTime)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        for (var i = 0; i < sequence.children.length; i++) {
          children.add(
            WorkoutNodeView(
              node: sequence.children[i],
              path: '$path/children/$i',
              view: view,
            ),
          );
        }
      case WorkoutRepeat repeat:
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.repeat_rounded,
                  size: 20,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${s['workout_repeat']} ${workoutRange(repeat.count)}×${repeat.label == null ? '' : ' · ${repeat.label!}'}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        children.add(
          WorkoutNodeView(node: repeat.body, path: '$path/body', view: view),
        );
        if (repeat.between != null) {
          children.add(
            WorkoutNodeView(
              node: repeat.between!,
              path: '$path/between',
              view: view,
              between: true,
            ),
          );
        }
      case WorkoutChoice choice:
        line(choice.label ?? s['workout_choose'], strong: true);
        line(choice.reason);
        for (var i = 0; i < choice.options.length; i++) {
          final option = choice.options[i];
          children.add(
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: colors.outlineVariant, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    option.label +
                        (option.audience == null
                            ? ''
                            : ' · ${option.audience!}'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  WorkoutNodeView(
                    node: option.plan,
                    path: '$path/options/$i/plan',
                    view: view,
                  ),
                ],
              ),
            ),
          );
        }
    }
    children.addAll(view.notes(node.notes));
    children.addAll(view.warnings(path, leaf: node is WorkoutStep));
    final framed = node is WorkoutRepeat || node is WorkoutStep;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: framed ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: !framed
          ? null
          : BoxDecoration(
              color: node is WorkoutRepeat
                  ? colors.primaryContainer
                  : colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outlineVariant),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
