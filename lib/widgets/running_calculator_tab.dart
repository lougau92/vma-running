import 'package:app_feedback/app_feedback.dart' show FeedbackContextScope;
import 'package:flutter/material.dart';

import '../calculator_draft.dart';
import 'running_calculator_page.dart';

class RunningCalculatorTab extends StatefulWidget {
  const RunningCalculatorTab({
    super.key,
    required this.savedVma,
    required this.onNavigatePage,
  });

  final double? savedVma;
  final ValueChanged<int> onNavigatePage;

  @override
  State<RunningCalculatorTab> createState() => _RunningCalculatorTabState();
}

class _RunningCalculatorTabState extends State<RunningCalculatorTab> {
  RunningCalculatorDraft _draft = const RunningCalculatorDraft();
  late double? _vma;

  @override
  void initState() {
    super.initState();
    _vma = widget.savedVma;
  }

  @override
  void didUpdateWidget(covariant RunningCalculatorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.savedVma != widget.savedVma) {
      _vma = widget.savedVma;
    }
  }

  @override
  Widget build(BuildContext context) => FeedbackContextScope(
    id: 'calculator',
    isScreen: true,
    data: {
      'vmaKmh': _vma,
      'savedVmaKmh': widget.savedVma,
      'measures': [
        for (var index = 0; index < 4; index++) _draft.measureAt(index).name,
      ],
      'inputIndices': _draft.inputIndices,
    },
    child: RunningCalculatorPage(
      draft: _draft,
      vma: _vma,
      onVmaChanged: (value) => setState(() => _vma = value),
      onChanged: (draft) => setState(() => _draft = draft),
      onNavigatePage: widget.onNavigatePage,
    ),
  );
}
