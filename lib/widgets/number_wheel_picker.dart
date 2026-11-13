import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import '../app_localizations.dart';

/// A labelled wheel for numeric values, including formatted times or distances.
/// [initialIndex] is applied when the wheel is first mounted.
class NumberWheelPicker extends StatefulWidget {
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
  State<NumberWheelPicker> createState() => _NumberWheelPickerState();
}

class _NumberWheelPickerState extends State<NumberWheelPicker> {
  late int _selectedIndex = widget.initialIndex;
  late final _controller = FixedExtentScrollController(
    initialItem: widget.initialIndex,
  );

  int? _parseInput(String input) {
    final parser = widget.parseInput;
    if (parser != null) return parser(input, _selectedIndex);
    final value = input.trim().toLowerCase();
    for (var index = 0; index < widget.itemCount; index++) {
      if (widget.formatItem(index).trim().toLowerCase() == value) {
        return index;
      }
    }
    return null;
  }

  Future<void> _editSelectedValue() async {
    final controller = TextEditingController(
      text: widget.formatItem(_selectedIndex),
    );
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    final strings = AppLocalizations.of(context);
    final index = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final parsedIndex = _parseInput(controller.text);
          return AlertDialog(
            title: Text(widget.label),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  widget.inputKeyboardType ??
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: strings.enterNumber),
              onChanged: (_) => setDialogState(() {}),
              onSubmitted: (_) {
                if (parsedIndex != null) {
                  Navigator.of(dialogContext).pop(parsedIndex);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: parsedIndex == null
                    ? null
                    : () => Navigator.of(dialogContext).pop(parsedIndex),
                child: Text(strings.save),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();

    if (index == null || !mounted || index == _selectedIndex) return;
    await _controller.animateToItem(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(widget.label, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      SizedBox(
        height: 180,
        child: Semantics(
          label: widget.label,
          child: CupertinoPicker.builder(
            scrollController: _controller,
            itemExtent: 40,
            childCount: widget.itemCount,
            onSelectedItemChanged: (index) {
              setState(() => _selectedIndex = index);
              widget.onChanged(index);
            },
            itemBuilder: (context, index) {
              final text = Text(
                widget.formatItem(index),
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
              if (index != _selectedIndex) return Center(child: text);
              return Center(
                child: Tooltip(
                  message: AppLocalizations.of(context).enterNumber,
                  child: InkWell(
                    onTap: _editSelectedValue,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: text),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}
