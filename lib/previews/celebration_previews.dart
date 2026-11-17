import 'package:flutter/material.dart';

import '../widgets/vma_change_celebration.dart';
import 'preview_support.dart';

@ResponsivePreview(group: 'Celebration', name: 'VMA update with replay')
Widget vmaCelebrationPreview() => const _CelebrationPreview();

class _CelebrationPreview extends StatefulWidget {
  const _CelebrationPreview();
  @override
  State<_CelebrationPreview> createState() => _CelebrationPreviewState();
}

class _CelebrationPreviewState extends State<_CelebrationPreview> {
  bool _showCelebration = true;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Center(
        child: FilledButton(
          onPressed: () => setState(() => _showCelebration = true),
          child: const Text('Rejouer'),
        ),
      ),
      if (_showCelebration)
        VmaChangeCelebration(
          onComplete: () {
            if (mounted) setState(() => _showCelebration = false);
          },
        ),
    ],
  );
}
