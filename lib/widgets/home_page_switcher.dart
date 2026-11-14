import 'package:flutter/material.dart';

import 'page_swipe_region.dart';

class HomePageSwitcher extends StatelessWidget {
  const HomePageSwitcher({
    super.key,
    required this.pageIndex,
    required this.pageCount,
    required this.visitedPageIndices,
    required this.allowTableEdgeSwipes,
    required this.onSwipe,
    required this.pageBuilder,
  });

  final int pageIndex;
  final int pageCount;
  final Set<int> visitedPageIndices;
  final bool allowTableEdgeSwipes;
  final ValueChanged<int> onSwipe;
  final IndexedWidgetBuilder pageBuilder;

  @override
  Widget build(BuildContext context) => PageSwipeRegion(
    pageIndex: pageIndex,
    allowTableEdgeSwipes: allowTableEdgeSwipes,
    onSwipe: onSwipe,
    child: Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < pageCount; index++)
          if (visitedPageIndices.contains(index))
            Offstage(
              key: ValueKey(index),
              offstage: index != pageIndex,
              child: TickerMode(
                enabled: index == pageIndex,
                child: pageBuilder(context, index),
              ),
            ),
      ],
    ),
  );
}
