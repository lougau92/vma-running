import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/vma_pace.dart';
import 'package:vma_running/vma_table.dart';

void main() {
  for (final width in [360.0, 1440.0]) {
    testWidgets('intensity table fits and scrolls at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: VmaPaceTable(
                  entries: VmaPaceCalculator().buildTable(
                    13,
                    minPercent: 60,
                    maxPercent: 120,
                    step: 5,
                    distanceMeters: 400,
                  ),
                  onEditPercentages: () {},
                  distanceMeters: 400,
                  onEditDistance: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final tables = find.byType(DataTable);
      final pinned = tester.getRect(tables.first);
      final scrolling = tester.getRect(tables.last);
      final horizontal = tester.widget<SingleChildScrollView>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      );
      if (width > 900) {
        expect((pinned.left + scrolling.right) / 2, closeTo(width / 2, 0.01));
        expect(horizontal.controller!.position.maxScrollExtent, 0);
      } else {
        expect(horizontal.controller!.position.maxScrollExtent, greaterThan(0));
        horizontal.controller!.jumpTo(
          horizontal.controller!.position.maxScrollExtent,
        );
        await tester.pump();
        expect(tester.getRect(tables.first), pinned);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
