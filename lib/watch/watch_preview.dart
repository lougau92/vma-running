import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../workouts/workout_format.dart';
import 'watch_workout.dart';

class WatchExportInputs extends StatelessWidget {
  const WatchExportInputs({
    super.key,
    required this.inputs,
    required this.enabled,
    required this.onChanged,
  });

  final List<ExportInput> inputs;
  final bool enabled;
  final void Function(String path, double value) onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final input in inputs)
        Padding(
          key: ValueKey(input.path),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _ExportInputField(
            input: input,
            enabled: enabled,
            onChanged: (value) => onChanged(input.path, value),
          ),
        ),
    ],
  );
}

class _ExportInputField extends StatelessWidget {
  const _ExportInputField({
    required this.input,
    required this.enabled,
    required this.onChanged,
  });

  final ExportInput input;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = input.options;
    if (options != null) {
      return DropdownButtonFormField<double>(
        initialValue: input.value,
        isExpanded: true,
        decoration: InputDecoration(labelText: input.label),
        items: [
          for (var i = 0; i < options.length; i++)
            DropdownMenuItem(
              value: i.toDouble(),
              child: Text(options[i], overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: enabled
            ? (v) {
                if (v != null) onChanged(v);
              }
            : null,
      );
    }
    final bounds = input.bounds!;
    final current = input.value;
    return TextFormField(
      enabled: enabled,
      initialValue: current != null && current.isFinite
          ? workoutNumber(current)
          : null,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: input.label,
        helperText: '${workoutNumber(bounds.min)}–${workoutNumber(bounds.max)}',
        errorText: input.resolved
            ? null
            : AppLocalizations.of(context)['garmin_range_error'],
      ),
      onChanged: (text) =>
          onChanged(double.tryParse(text.replaceAll(',', '.')) ?? double.nan),
    );
  }
}

class WatchStepPreview extends StatelessWidget {
  const WatchStepPreview({
    super.key,
    required this.role,
    required this.end,
    this.pace,
    this.notes,
    this.number,
  });

  final String role, end;
  final String? pace, notes;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final (label, icon) = switch (role) {
      'warmup' => (s.warmup, Icons.wb_twilight),
      'cooldown' => (s.cooldown, Icons.nights_stay_outlined),
      'recovery' || 'rest' => (s.recovery, Icons.pause_circle_outline),
      _ => (s.sessionContent, Icons.bolt),
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: colors.surfaceContainerLow,
      child: ListTile(
        leading: Icon(icon, color: colors.primary),
        title: Text(number == null ? label : '$number. $label'),
        trailing: Text(end),
        subtitle: pace == null && notes == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pace != null) Text(pace!),
                  if (notes != null) WatchPreviewNotes(text: notes!),
                ],
              ),
      ),
    );
  }
}

class WatchPreviewNotes extends StatelessWidget {
  const WatchPreviewNotes({super.key, required this.text, this.title});

  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

String watchPreviewPace(int fast, int slow) {
  String pace(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  return fast == slow ? '${pace(fast)} /km' : '${pace(fast)}–${pace(slow)} /km';
}
