import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import '../app_localizations.dart';

/// A labelled wheel whose selected number can also be edited in place.
/// [initialIndex] is applied when the wheel is first mounted.
class NumberWheelPicker extends StatelessWidget {
  const NumberWheelPicker({
    super.key,
    required this.label,
    required this.initialIndex,
    required this.itemCount,
    required this.formatItem,
    required this.onChanged,
    this.parseInput,
    this.inputKeyboardType,
  }) : assert(itemCount > 0),
       assert(initialIndex >= 0 && initialIndex < itemCount);

  final String label;
  final int initialIndex;
  final int itemCount;
  final String Function(int) formatItem;
  final ValueChanged<int> onChanged;
  final int? Function(String input, int currentIndex)? parseInput;
  final TextInputType? inputKeyboardType;

  @override
  Widget build(BuildContext context) => _EditableWheel<int>(
    label: label,
    values: List.generate(itemCount, (index) => index),
    initialValue: initialIndex,
    formatValue: formatItem,
    parseInput: (input, current) {
      final parser = parseInput;
      if (parser != null) {
        final index = parser(input, current);
        return index != null && index >= 0 && index < itemCount ? index : null;
      }
      final text = input.trim().toLowerCase();
      for (var index = 0; index < itemCount; index++) {
        if (formatItem(index).trim().toLowerCase() == text) return index;
      }
      return null;
    },
    onChanged: onChanged,
    inputKeyboardType: inputKeyboardType,
  );
}

/// A numeric preset wheel that also preserves custom values entered by typing.
class NumberValueWheelPicker extends StatelessWidget {
  const NumberValueWheelPicker({
    super.key,
    required this.label,
    required this.initialValue,
    required this.values,
    required this.formatValue,
    required this.parseInput,
    required this.onChanged,
    this.inputKeyboardType,
    this.onInputCompleted,
    this.minValue = 0,
    this.maxValue = double.infinity,
  });

  final String label;
  final double initialValue;
  final List<double> values;
  final String Function(double) formatValue;
  final double? Function(String input, double currentValue) parseInput;
  final ValueChanged<double> onChanged;

  /// Reports the final typed value once on Done, focus loss, or route dismissal.
  final ValueChanged<double>? onInputCompleted;
  final TextInputType? inputKeyboardType;
  final double minValue;
  final double maxValue;

  @override
  Widget build(BuildContext context) => _EditableWheel<double>(
    label: label,
    values: {...values, initialValue}.toList()..sort(),
    initialValue: initialValue,
    formatValue: formatValue,
    parseInput: (input, current) {
      final text = input.trim().toLowerCase();
      // Formatted presets may contain units that the numeric parser omits.
      for (final value in values) {
        if (formatValue(value).trim().toLowerCase() == text) return value;
      }
      final value = parseInput(input, current);
      return value != null &&
              value.isFinite &&
              value >= minValue &&
              value <= maxValue
          ? value
          : null;
    },
    compare: (a, b) => a.compareTo(b),
    onChanged: onChanged,
    onInputCompleted: onInputCompleted,
    inputKeyboardType: inputKeyboardType,
  );
}

class _EditableWheel<T> extends StatefulWidget {
  const _EditableWheel({
    required this.label,
    required this.values,
    required this.initialValue,
    required this.formatValue,
    required this.parseInput,
    required this.onChanged,
    this.compare,
    this.inputKeyboardType,
    this.onInputCompleted,
  });

  final String label;
  final List<T> values;
  final T initialValue;
  final String Function(T) formatValue;
  final T? Function(String, T) parseInput;
  final ValueChanged<T> onChanged;
  final ValueChanged<T>? onInputCompleted;
  final Comparator<T>? compare;
  final TextInputType? inputKeyboardType;

  @override
  State<_EditableWheel<T>> createState() => _EditableWheelState<T>();
}

class _EditableWheelState<T> extends State<_EditableWheel<T>> {
  late final List<T> _values = [...widget.values];
  late T _selected = widget.initialValue;
  late T _inputReference = widget.initialValue;
  late final _wheelController = FixedExtentScrollController(
    initialItem: _values.indexOf(_selected),
  );
  final _textController = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;
  bool _invalid = false;
  bool _typedValidValue = false;
  bool _syncingWheel = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(covariant _EditableWheel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editing ||
        (widget.values.length == oldWidget.values.length &&
            Iterable<int>.generate(widget.values.length).every(
              (index) => widget.values[index] == oldWidget.values[index],
            ))) {
      return;
    }
    _values
      ..clear()
      ..addAll({...widget.values, _selected});
    if (widget.compare != null) _values.sort(widget.compare);
    _syncWheel();
  }

  void _focusChanged() {
    if (!_focus.hasFocus) _finishEditing();
  }

  void _finishEditing() {
    if (!_editing) return;
    if (_invalid) _textController.text = widget.formatValue(_selected);
    setState(() {
      _editing = false;
      if (!_values.contains(_selected)) {
        _values.add(_selected);
        if (widget.compare != null) _values.sort(widget.compare);
      }
    });
    _syncWheel();
    if (_typedValidValue && !_invalid) {
      widget.onInputCompleted?.call(_selected);
    }
  }

  void _syncWheel() {
    _syncingWheel = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_wheelController.hasClients) {
        _wheelController.jumpToItem(_values.indexOf(_selected));
      }
      // Scroll notifications from the programmatic jump are delivered next frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _syncingWheel = false,
      );
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  void _startEditing() {
    _inputReference = _selected;
    _textController.text = widget.formatValue(_selected);
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );
    setState(() {
      _editing = true;
      _invalid = false;
      _typedValidValue = false;
    });
    _focus.requestFocus();
  }

  void _applyInput(String input) {
    final value = widget.parseInput(input, _inputReference);
    setState(() => _invalid = value == null);
    if (value == null) return;
    _typedValidValue = true;
    if (value == _selected) return;
    setState(() => _selected = value);
    // Preview immediately, but insert only the completed value into the wheel.
    widget.onChanged(value);
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _textController.dispose();
    _wheelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _finishEditing();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.label, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  ignoring: _editing,
                  child: Semantics(
                    label: widget.label,
                    child: CupertinoPicker.builder(
                      scrollController: _wheelController,
                      itemExtent: 40,
                      childCount: _values.length,
                      onSelectedItemChanged: (index) {
                        // Typing can insert a value before the current index.
                        // Ignore the temporary old offset until the wheel syncs.
                        if (_editing || _syncingWheel) return;
                        final value = _values[index];
                        if (value == _selected) return;
                        setState(() {
                          _selected = value;
                          _invalid = false;
                        });
                        widget.onChanged(value);
                      },
                      itemBuilder: (context, index) {
                        final value = _values[index];
                        if (_editing && value == _selected) {
                          return const SizedBox.shrink();
                        }
                        final text = FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.formatValue(value),
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        );
                        if (value != _selected) return Center(child: text);
                        return Center(
                          child: Tooltip(
                            message: strings.enterNumber,
                            child: InkWell(
                              onTap: _startEditing,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: text,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_editing)
                  TextField(
                    controller: _textController,
                    focusNode: _focus,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                    keyboardType:
                        widget.inputKeyboardType ??
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      errorText: _invalid ? strings.enterNumber : null,
                      errorMaxLines: 2,
                    ),
                    onChanged: _applyInput,
                    onSubmitted: (_) => _focus.unfocus(),
                    onTapOutside: (_) => _focus.unfocus(),
                  ),
              ],
            ),
          ),
          if (_invalid && !_editing)
            Text(
              strings.enterNumber,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
