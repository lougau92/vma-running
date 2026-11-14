import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/widgets/page_swipe_region.dart';

Widget _app({
  required ValueChanged<int> onSwipe,
  Widget child = const SizedBox.expand(),
  int pageIndex = 0,
  bool reducedMotion = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: PageSwipeRegion(
            pageIndex: pageIndex,
            allowTableEdgeSwipes: true,
            onSwipe: onSwipe,
            child: child,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('body drags navigate once and short drags stay put', (
    tester,
  ) async {
    final swipes = <int>[];
    await tester.pumpWidget(_app(onSwipe: swipes.add));
    await tester.drag(find.byType(PageSwipeRegion), const Offset(-130, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageSwipeRegion), const Offset(130, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageSwipeRegion), const Offset(-30, 0));
    await tester.pumpAndSettle();
    expect(swipes, [1, -1]);
  });

  testWidgets(
    'scrolls table first, then hands a continued edge drag to paging',
    (tester) async {
      final swipes = <int>[];
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          onSwipe: swipes.add,
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: const SizedBox(width: 900, height: 200),
          ),
        ),
      );
      final scroll = find.byType(SingleChildScrollView);
      await tester.drag(scroll, const Offset(-130, 0));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(swipes, isEmpty);

      controller.jumpTo(controller.position.maxScrollExtent - 40);
      await tester.pump();
      await tester.drag(scroll, const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(swipes, [1]);

      // A new outward swipe at the other edge works in the opposite direction.
      controller.jumpTo(0);
      await tester.pump();
      await tester.drag(scroll, const Offset(130, 0));
      await tester.pumpAndSettle();
      expect(swipes, [1, -1]);

      await tester.drag(scroll, const Offset(30, 0));
      await tester.pumpAndSettle();
      expect(swipes, [1, -1]);
    },
  );

  testWidgets('mouse wheel and programmatic scrolling never navigate', (
    tester,
  ) async {
    final swipes = <int>[];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        onSwipe: swipes.add,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          child: const SizedBox(width: 900, height: 200),
        ),
      ),
    );
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(PageSwipeRegion)),
        scrollDelta: const Offset(500, 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(swipes, isEmpty);
  });

  testWidgets('slider and vertical scroll gestures keep their own behavior', (
    tester,
  ) async {
    final swipes = <int>[];
    var value = 0.5;
    await tester.pumpWidget(
      _app(
        onSwipe: swipes.add,
        child: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              children: [
                Slider(
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
                const SizedBox(height: 900),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(value, greaterThan(0.5));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -130),
    );
    await tester.pumpAndSettle();
    expect(swipes, isEmpty);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets('page transition respects reduced motion=$reducedMotion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(onSwipe: (_) {}, reducedMotion: reducedMotion),
      );
      await tester.pumpWidget(
        _app(onSwipe: (_) {}, pageIndex: 1, reducedMotion: reducedMotion),
      );
      final transition = tester.widget<FractionalTranslation>(
        find.descendant(
          of: find.byType(PageSwipeRegion),
          matching: find.byType(FractionalTranslation),
        ),
      );
      expect(transition.translation.dx, reducedMotion ? 0 : greaterThan(0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FractionalTranslation>(
              find.descendant(
                of: find.byType(PageSwipeRegion),
                matching: find.byType(FractionalTranslation),
              ),
            )
            .translation,
        Offset.zero,
      );
    });
  }
}
