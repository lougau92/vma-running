import 'package:flutter/material.dart';

import '../app_localizations.dart' show AppLocalizations, DynamicStrings;
import '../presets.dart';
import '../running/running.dart';
import '../widgets/number_picker_dialog.dart';
import '../widgets/number_wheel_picker.dart';
import 'running_calculator_draft.dart';

class RunningCalculatorPage extends StatelessWidget {
  const RunningCalculatorPage({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.vma,
    required this.onVmaChanged,
  });

  final RunningCalculatorDraft draft;
  final ValueChanged<RunningCalculatorDraft> onChanged;

  /// Calculator-only VMA, initially copied from the user's saved VMA.
  final double? vma;
  final ValueChanged<double> onVmaChanged;

  Future<void> _editVma(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => NumberPickerDialog(
      title: AppLocalizations.of(context).setVma,
      initialValue: isPositiveFinite(vma) ? vma!.clamp(1.0, 99.99) : 18,
      formatValue: AppLocalizations.of(context).yourVma,
      onChanged: onVmaChanged,
    ),
  );

  Future<void> _editValue(BuildContext context, int index) {
    final measure = draft.measureAt(index);
    final current = draft.displayValueAt(index, vma);
    final initial =
        _pickerValue(measure, current, vma) ??
        _pickerValue(measure, measure.example, vma)!;
    var edited = draft.activate(index, _formatValue(measure, initial));
    onChanged(edited);
    final label = _label(AppLocalizations.of(context), measure);
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: Text(label),
        content: SizedBox(
          width: 320,
          child: NumberValueWheelPicker(
            key: ValueKey('calculator-picker-${measure.name}'),
            label: label,
            initialValue: initial,
            values: _presets(measure),
            minValue: double.minPositive,
            formatValue: (value) => _formatValue(measure, value),
            parseInput: (input, _) => _pickerValue(measure, input, vma),
            inputKeyboardType:
                measure == RunningMeasure.time || measure == RunningMeasure.pace
                ? TextInputType.text
                : const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              edited = edited.edit(index, _formatValue(measure, value));
              onChanged(edited);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('calculator-vma'),
              onPressed: () => _editVma(context),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                !isPositiveFinite(vma) ? strings.setVma : strings.yourVma(vma!),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 560
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var index = 0; index < 4; index++)
                    SizedBox(width: width, child: _tile(context, index)),
                ],
              );
            },
          ),
          if (draft.calculate(vma) == null) ...[
            const SizedBox(height: 12),
            Text(
              strings['calculatorIncomplete'],
              key: const ValueKey('calculator-incomplete'),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, int index) {
    final strings = AppLocalizations.of(context);
    final measure = draft.measureAt(index);
    final isInput = draft.isInput(index);
    final value = draft.displayValueAt(index, vma);
    final missingVma =
        measure == RunningMeasure.intensity && !isPositiveFinite(vma);
    final invalid =
        isInput &&
        value.isNotEmpty &&
        parseRunningValue(measure, value, vma: vma) == null;
    final otherMeasures = [
      for (var other = 0; other < 4; other++)
        if (other != index) draft.measureAt(other),
    ];
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status =
        strings[isInput ? 'calculatorInput' : 'calculatorCalculated'];
    final error = missingVma
        ? strings['calculatorNeedsVma']
        : invalid
        ? strings['calculatorInvalid']
        : null;
    void edit() => missingVma ? _editVma(context) : _editValue(context, index);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DropdownButton<RunningMeasure>(
                        key: ValueKey(
                          'calculator-measure-$index-${measure.name}',
                        ),
                        value: measure,
                        isExpanded: true,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        iconSize: 18,
                        iconEnabledColor: colors.onPrimaryContainer,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        items: [
                          for (final option in RunningMeasure.values)
                            if (!otherMeasures.contains(option))
                              DropdownMenuItem(
                                value: option,
                                child: Text(_label(strings, option)),
                              ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            onChanged(draft.select(index, value));
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: '${_label(strings, measure)}, $status',
              value: value,
              hint: error,
              onTap: edit,
              child: ExcludeSemantics(
                child: InkWell(
                  key: ValueKey('calculator-value-$index'),
                  onTap: edit,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    isEmpty: value.isEmpty,
                    decoration: InputDecoration(
                      errorText: error,
                      errorMaxLines: 2,
                    ),
                    child: Text(
                      value,
                      key: ValueKey('calculator-display-$index'),
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Validate through the domain parser, then retain the selected card's units.
double? _pickerValue(RunningMeasure measure, String input, double? vma) {
  if (parseRunningValue(measure, input, vma: vma) == null) return null;
  return switch (measure) {
    RunningMeasure.time => parseRunningDuration(input),
    RunningMeasure.pace => parseRunningDuration(input, allowHours: false),
    _ => double.tryParse(input.trim().replaceAll(',', '.')),
  };
}

String _formatValue(RunningMeasure measure, double value) {
  final numeric = value.toString().replaceFirst(RegExp(r'\.0$'), '');
  final duration = switch (measure) {
    RunningMeasure.time => formatRunningDuration(value),
    RunningMeasure.pace => formatPacePerKm(RunningSpeed.fromPaceSeconds(value)),
    _ => null,
  };
  // Keep fractional seconds and long/custom durations exact when the compact
  // display format would round them or could not be parsed back.
  return duration != null &&
          parseRunningDuration(
                duration,
                allowHours: measure != RunningMeasure.pace,
              ) ==
              value
      ? duration
      : numeric;
}

List<double> _presets(RunningMeasure measure) => switch (measure) {
  RunningMeasure.distance => [
    for (final meters in presetDistances()) meters / 1000,
  ],
  RunningMeasure.time => presetTimesSeconds(),
  RunningMeasure.pace => List.generate(120, (index) => (index + 1) * 15.0),
  RunningMeasure.speed => List.generate(80, (index) => (index + 1) / 2),
  RunningMeasure.intensity => List.generate(60, (index) => (index + 1) * 5.0),
};

String _label(AppLocalizations strings, RunningMeasure measure) =>
    strings[switch (measure) {
      RunningMeasure.distance => 'calculatorDistance',
      RunningMeasure.time => 'calculatorTime',
      RunningMeasure.speed => 'speedKmh',
      RunningMeasure.pace => 'calculatorPace',
      RunningMeasure.intensity => 'calculatorIntensity',
    }];
