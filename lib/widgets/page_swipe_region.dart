import 'package:flutter/material.dart';

/// Navigates with horizontal drags, including deliberate drags past table edges.
/// Scroll wheels and ballistic scrolling never trigger page changes.
class PageSwipeRegion extends StatefulWidget {
  const PageSwipeRegion({
    super.key,
    required this.pageIndex,
    required this.onSwipe,
    required this.child,
    this.allowTableEdgeSwipes = false,
  });

  final int pageIndex;
  final ValueChanged<int> onSwipe;
  final Widget child;
  final bool allowTableEdgeSwipes;

  @override
  State<PageSwipeRegion> createState() => _PageSwipeRegionState();
}

class _PageSwipeRegionState extends State<PageSwipeRegion>
    with SingleTickerProviderStateMixin {
  static const _threshold = 70.0;
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final _curve = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeOutCubic,
  );
  double _direction = 1;
  double _drag = 0;
  double _edgeDrag = 0;
  bool _scrollDrag = false;

  @override
  void didUpdateWidget(covariant PageSwipeRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageIndex == widget.pageIndex) return;
    _direction = widget.pageIndex > oldWidget.pageIndex ? 1 : -1;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward(from: 0);
    }
    _drag = 0;
    _edgeDrag = 0;
    _scrollDrag = false;
  }

  @override
  void dispose() {
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _finishSwipe(double distance) {
    if (distance.abs() >= _threshold) widget.onSwipe(distance > 0 ? 1 : -1);
  }

  bool _onScroll(ScrollNotification notification) {
    if (!widget.allowTableEdgeSwipes ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _scrollDrag = notification.dragDetails != null;
      _edgeDrag = 0;
    } else if (_scrollDrag && notification is OverscrollNotification) {
      if (notification.dragDetails != null) {
        // Positive overscroll means swiping toward the next page.
        _addEdgeDrag(notification.overscroll);
      }
    } else if (_scrollDrag &&
        notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final metrics = notification.metrics;
      if (!metrics.outOfRange) {
        _edgeDrag = 0;
      } else {
        // Bouncing scroll physics reports movement outside the range here.
        _edgeDrag = metrics.pixels < metrics.minScrollExtent
            ? metrics.pixels - metrics.minScrollExtent
            : metrics.pixels - metrics.maxScrollExtent;
      }
    } else if (notification is ScrollEndNotification) {
      final distance = _edgeDrag;
      _edgeDrag = 0;
      _scrollDrag = false;
      _finishSwipe(distance);
    }
    return false;
  }

  void _addEdgeDrag(double delta) {
    if (_edgeDrag.sign != delta.sign) _edgeDrag = 0;
    _edgeDrag += delta;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _drag = 0,
          onHorizontalDragUpdate: (details) => _drag -= details.delta.dx,
          onHorizontalDragCancel: () => _drag = 0,
          onHorizontalDragEnd: (_) {
            final distance = _drag;
            _drag = 0;
            _finishSwipe(distance);
          },
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _curve,
              child: widget.child,
              builder: (context, child) => FractionalTranslation(
                translation: Offset(_direction * 0.08 * (1 - _curve.value), 0),
                child: Opacity(opacity: 0.6 + 0.4 * _curve.value, child: child),
              ),
            ),
          ),
        ),
      );
}
