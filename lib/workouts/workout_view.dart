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
    final colors = Theme.of(context).colorScheme;
    final background = switch (kind) {
      0 => colors.tertiaryContainer,
      1 => colors.primaryContainer,
      _ => colors.secondaryContainer,
    };
    final foreground = switch (kind) {
      0 => colors.onTertiaryContainer,
      1 => colors.onPrimaryContainer,
      _ => colors.onSecondaryContainer,
    };
    return FeedbackContextScope(
      id: ['warmup', 'intervals', 'cooldown'][kind],
      child: Card(
        color: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: foreground),
                ),
                const SizedBox(height: 10),
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
                  ),
              ],
            ),
          ),
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
    final children = <Widget>[];
    void line(String text, {bool strong = false}) => children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          text,
          style: strong ? const TextStyle(fontWeight: FontWeight.w600) : null,
        ),
      ),
    );
    if (node.optional) line(s['workout_optional'], strong: true);
    if (between && node is! WorkoutStep) {
      line(s['workout_between'], strong: true);
    }
    switch (node) {
      case WorkoutStep step:
        final end = formatWorkoutEnd(step.end, s);
        final label = step.label;
        final heading = [
          s['workout_role_${step.role}'],
          end,
          if (label != null &&
              label.toLowerCase() != end.toLowerCase() &&
              label.toLowerCase() !=
                  s['workout_role_${step.role}'].toLowerCase())
            label,
          if (between) s['workout_between'],
        ].join(' · ');
        line(heading, strong: true);
        for (final target in step.targets) {
          line(formatWorkoutTarget(target, s, view.vma));
        }
        if (step.role == 'recovery' || step.movement != null) {
          line(formatWorkoutMovement(step.movement, s));
        }
      case WorkoutSequence sequence:
        if (sequence.label != null) line(sequence.label!, strong: true);
        if (sequence.declaredDuration != null) {
          line(
            '${s['workout_budget']}: ${workoutRange(sequence.declaredDuration!, workoutTime)}',
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
        line(
          '${s['workout_repeat']} ${workoutRange(repeat.count)}×${repeat.label == null ? '' : ' · ${repeat.label}'}',
          strong: true,
        );
        children.add(
          _indent(
            context,
            WorkoutNodeView(node: repeat.body, path: '$path/body', view: view),
          ),
        );
        if (repeat.between != null) {
          children.add(
            _indent(
              context,
              WorkoutNodeView(
                node: repeat.between!,
                path: '$path/between',
                view: view,
                between: true,
              ),
            ),
          );
        }
      case WorkoutChoice choice:
        line(choice.label ?? s['workout_choose'], strong: true);
        line(choice.reason);
        for (var i = 0; i < choice.options.length; i++) {
          final option = choice.options[i];
          line(
            '${option.label}${option.audience == null ? '' : ' · ${option.audience}'}',
            strong: true,
          );
          children.add(
            _indent(
              context,
              WorkoutNodeView(
                node: option.plan,
                path: '$path/options/$i/plan',
                view: view,
              ),
            ),
          );
        }
    }
    children.addAll(view.notes(node.notes));
    children.addAll(view.warnings(path, leaf: node is WorkoutStep));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _indent(BuildContext context, Widget child) => Container(
    margin: const EdgeInsets.only(left: 2, top: 4),
    padding: const EdgeInsets.only(left: 12),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: DefaultTextStyle.of(
            context,
          ).style.color!.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
    ),
    child: child,
  );
}
