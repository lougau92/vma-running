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
    final text = Theme.of(context).textTheme;
    final instructions = notes;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            number == null ? label : '$number. $label',
                            style: text.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(end, style: text.labelLarge),
                      ],
                    ),
                    if (pace != null || instructions?.trim().isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          [
                            if (pace != null) pace!,
                            if (instructions != null &&
                                instructions.trim().isNotEmpty)
                              instructions,
                          ].join('\n'),
                          style: text.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class WatchExportStatus extends StatelessWidget {
  const WatchExportStatus({
    super.key,
    required this.message,
    this.detail,
    this.success = true,
  });

  final String message;
  final String? detail;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = success
        ? colors.onPrimaryContainer
        : colors.onErrorContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: success ? colors.primaryContainer : colors.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? colors.primary : foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
