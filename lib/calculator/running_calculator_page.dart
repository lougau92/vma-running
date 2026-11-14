import 'package:flutter/material.dart';

import '../app_localizations.dart' show AppLocalizations, DynamicStrings;
import '../running/running.dart' show isPositiveFinite;
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
    final otherMeasures = [
      for (var other = 0; other < 4; other++)
        if (other != index) draft.measureAt(other),
    ];
    final invalid =
        isInput &&
        value.isNotEmpty &&
        parseRunningValue(measure, value, vma: vma) == null;
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
                  child: DropdownButtonFormField<RunningMeasure>(
                    key: ValueKey('calculator-measure-$index-${measure.name}'),
                    initialValue: measure,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: strings['calculatorType'],
                    ),
                    items: [
                      for (final option in RunningMeasure.values)
                        if (!otherMeasures.contains(option))
                          DropdownMenuItem(
                            value: option,
                            child: Text(_label(strings, option)),
                          ),
                    ],
                    onChanged: (value) {
                      if (value != null) onChanged(draft.select(index, value));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message:
                      strings[isInput
                          ? 'calculatorInput'
                          : 'calculatorCalculated'],
                  child: Icon(
                    isInput ? Icons.edit_outlined : Icons.functions,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CalculatorValueField(
              key: ValueKey('calculator-value-$index'),
              measure: measure,
              value: value,
              isInput: isInput,
              invalid: invalid,
              vmaMissing:
                  measure == RunningMeasure.intensity && !isPositiveFinite(vma),
              onActivate: () => onChanged(draft.activate(index, value)),
              onChanged: (text) => onChanged(draft.edit(index, text)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalculatorValueField extends StatefulWidget {
  const _CalculatorValueField({
    super.key,
    required this.measure,
    required this.value,
    required this.isInput,
    required this.invalid,
    required this.vmaMissing,
    required this.onActivate,
    required this.onChanged,
  });

  final RunningMeasure measure;
  final String value;
  final bool isInput;
  final bool invalid;
  final bool vmaMissing;
  final VoidCallback onActivate;
  final ValueChanged<String> onChanged;

  @override
  State<_CalculatorValueField> createState() => _CalculatorValueFieldState();
}

class _CalculatorValueFieldState extends State<_CalculatorValueField> {
  final FocusNode _focusNode = FocusNode();
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _CalculatorValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.measure != widget.measure ||
        (!widget.isInput && oldWidget.value != widget.value) ||
        (oldWidget.isInput && !widget.isInput)) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _activate() {
    widget.onActivate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final duration =
        widget.measure == RunningMeasure.time ||
        widget.measure == RunningMeasure.pace;
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      readOnly: !widget.isInput,
      onTap: widget.isInput ? null : _activate,
      keyboardType: duration
          ? TextInputType.datetime
          : const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: _label(strings, widget.measure),
        helperText:
            strings[widget.isInput
                ? duration
                      ? 'calculatorDurationHelp'
                      : 'calculatorNumberHelp'
                : 'calculatorTapToEdit'],
        helperMaxLines: 4,
        errorText: widget.invalid
            ? strings[widget.vmaMissing
                  ? 'calculatorNeedsVma'
                  : 'calculatorInvalid']
            : null,
        errorMaxLines: 2,
        suffixIcon: widget.isInput ? null : const Icon(Icons.edit_outlined),
      ),
      onChanged: widget.isInput ? widget.onChanged : null,
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
