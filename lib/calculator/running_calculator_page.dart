import 'package:flutter/material.dart';

import '../app_localizations.dart' show AppLocalizations, DynamicStrings;
import '../running/running.dart'
    show RunningSplit, isPositiveFinite, formatPacePerKm, formatRunningDuration;
import 'running_calculator_draft.dart';

class RunningCalculatorPage extends StatelessWidget {
  const RunningCalculatorPage({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.vma,
    required this.onEditVma,
  });

  final RunningCalculatorDraft draft;
  final ValueChanged<RunningCalculatorDraft> onChanged;
  final double? vma;
  final VoidCallback onEditVma;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final result = draft.calculate(vma);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings['calculatorTab'],
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(strings['calculatorHelp']),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onEditVma,
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
                  for (var i = 0; i < 2; i++)
                    SizedBox(width: width, child: _input(context, i)),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            strings['calculatorResults'],
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (result == null)
            Text(
              strings['calculatorIncomplete'],
              key: const ValueKey('calculator-incomplete'),
            )
          else
            _results(context, result),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _input(BuildContext context, int index) {
    final strings = AppLocalizations.of(context);
    final measure = index == 0 ? draft.first : draft.second;
    final other = index == 0 ? draft.second : draft.first;
    final text = index == 0 ? draft.firstText : draft.secondText;
    final duration =
        measure == RunningMeasure.time || measure == RunningMeasure.pace;
    final invalid =
        text.isNotEmpty && parseRunningValue(measure, text, vma: vma) == null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<RunningMeasure>(
              key: ValueKey('calculator-measure-$index-${measure.name}'),
              initialValue: measure,
              isExpanded: true,
              decoration: InputDecoration(
                labelText:
                    strings[index == 0
                        ? 'calculatorFirst'
                        : 'calculatorSecond'],
              ),
              items: [
                for (final option in RunningMeasure.values)
                  if (option.quantity != other.quantity)
                    DropdownMenuItem(
                      value: option,
                      child: Text(_label(strings, option)),
                    ),
              ],
              onChanged: (value) {
                if (value != null) onChanged(draft.select(index, value));
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: ValueKey('calculator-value-$index-${measure.name}'),
              initialValue: text,
              keyboardType: duration
                  ? TextInputType.datetime
                  : const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: _label(strings, measure),
                helperText:
                    strings[duration
                        ? 'calculatorDurationHelp'
                        : 'calculatorNumberHelp'],
                helperMaxLines: 4,
                errorText: invalid
                    ? strings[measure == RunningMeasure.intensity &&
                              !isPositiveFinite(vma)
                          ? 'calculatorNeedsVma'
                          : 'calculatorInvalid']
                    : null,
                errorMaxLines: 2,
              ),
              onChanged: (value) => onChanged(draft.edit(index, value)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _results(BuildContext context, RunningSplit result) {
    final strings = AppLocalizations.of(context);
    final intensity = result.speed.percentOfVma(vma);
    final values = {
      RunningMeasure.distance: _number(result.distanceKm),
      RunningMeasure.time: formatRunningDuration(result.seconds),
      RunningMeasure.speed: _number(result.speed.kmh),
      RunningMeasure.pace: formatPacePerKm(result.speed),
      RunningMeasure.intensity: intensity == null ? '—' : _number(intensity),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 400
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in values.entries)
              SizedBox(
                width: width,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_label(strings, entry.key)),
                        const SizedBox(height: 4),
                        SelectableText(
                          entry.value,
                          key: ValueKey('calculator-result-${entry.key.name}'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (entry.key == RunningMeasure.intensity &&
                            !isPositiveFinite(vma))
                          Text(strings['calculatorNeedsVma']),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _label(AppLocalizations strings, RunningMeasure measure) =>
    strings[switch (measure) {
      RunningMeasure.distance => 'calculatorDistance',
      RunningMeasure.time => 'calculatorTime',
      RunningMeasure.speed => 'speedKmh',
      RunningMeasure.pace => 'calculatorPace',
      RunningMeasure.intensity => 'calculatorIntensity',
    }];

String _number(double value) => value < 0.01 || value >= 1e9
    ? value.toStringAsExponential(2)
    : value.toStringAsFixed(2);
