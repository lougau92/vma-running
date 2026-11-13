import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';

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
  }) : assert(itemCount > 0),
       assert(initialIndex >= 0 && initialIndex < itemCount);

  final String label;
  final int initialIndex;
  final int itemCount;
  final String Function(int) formatItem;
  final ValueChanged<int> onChanged;

  @override
  State<NumberWheelPicker> createState() => _NumberWheelPickerState();
}

class _NumberWheelPickerState extends State<NumberWheelPicker> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.initialIndex,
  );

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
            onSelectedItemChanged: widget.onChanged,
            itemBuilder: (context, index) => Center(
              child: Text(
                widget.formatItem(index),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
