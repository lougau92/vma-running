import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/vma_pace.dart';
import 'package:vma_running/vma_table.dart';
import 'package:vma_running/vma_times_table.dart';
import 'package:vma_running/running/running.dart';
import 'package:vma_running/theme.dart';

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

  testWidgets('editable columns can be dragged into the pinned position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var intensityEdits = 0;
    var distanceEdits = 0;
    await tester.pumpWidget(
      _app(
        VmaPaceTable(
          entries: _entries(),
          onEditPercentages: () => intensityEdits++,
          distanceMeters: 400,
          onEditDistance: () => distanceEdits++,
        ),
      ),
    );
    final strings = AppLocalizations(const Locale('en'));
    await tester.tap(find.text(strings.intensity));
    await tester.tap(find.text(strings.timeForDistanceLabel(400)));
    expect(intensityEdits, 1);
    expect(distanceEdits, 1);

    Future<void> moveTo(int source, int target) async {
      final handle = find.byKey(ValueKey('pace-column-handle-$source'));
      final destination = tester.getCenter(
        find.byKey(ValueKey('pace-column-$target')),
      );
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump();
      await gesture.moveTo(destination);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    String pinnedValue() {
      final table = tester.widget<DataTable>(find.byType(DataTable).first);
      return ((table.rows.first.cells.single.child as Align).child as Text)
          .data!;
    }

    expect(pinnedValue(), '60%');
    await moveTo(2, 0);
    expect(pinnedValue(), _entries().first.timeForDistance);
    await moveTo(0, 2);
    expect(pinnedValue(), '60%');
    expect(intensityEdits, 1);
    expect(distanceEdits, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('intensity stripes align across pinned and scrolling cells', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        VmaPaceTable(
          entries: _entries(),
          onEditPercentages: () {},
          distanceMeters: 400,
          onEditDistance: () {},
        ),
      ),
    );
    final tables = tester
        .widgetList<DataTable>(find.byType(DataTable))
        .toList();
    final colors = EnjambeeTheme.lightTheme().colorScheme;
    for (var index = 0; index < tables.first.rows.length; index++) {
      final expected = index.isEven
          ? colors.surface
          : colors.surfaceContainerLow;
      expect(tables.first.rows[index].color!.resolve({}), expected);
      expect(tables.last.rows[index].color!.resolve({}), expected);
    }
    final pinnedText = find.text('60%');
    final tableRect = tester.getRect(find.byType(DataTable).first);
    expect(tester.getCenter(pinnedText).dx, closeTo(tableRect.center.dx, 0.01));
    expect(find.byIcon(Icons.touch_app), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('times table centers the first value column in both modes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        VmaTimesTable(
          speed: RunningSpeed.fromKmh(15),
          minDistanceMeters: 100,
          maxDistanceMeters: 400,
          minTimeSeconds: 60,
          maxTimeSeconds: 300,
          onEditDistances: () {},
          onEditTimes: () {},
        ),
      ),
    );
    void checkTable() {
      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(
        (table.rows.first.cells[1].child as Align).alignment,
        Alignment.center,
      );
      expect(
        (table.rows.first.cells[2].child as Align).alignment,
        Alignment.centerLeft,
      );
      final colors = EnjambeeTheme.lightTheme().colorScheme;
      expect(table.rows[0].color!.resolve({}), colors.surface);
      expect(table.rows[1].color!.resolve({}), colors.surfaceContainerLow);
      expect(table.columns[1].headingRowAlignment, MainAxisAlignment.center);
    }

    checkTable();
    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pump();
    checkTable();
    expect(find.byIcon(Icons.touch_app), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

List<VmaPaceEntry> _entries() => VmaPaceCalculator().buildTable(
  13,
  minPercent: 60,
  maxPercent: 120,
  step: 5,
  distanceMeters: 400,
);

Widget _app(Widget child) => MaterialApp(
  theme: EnjambeeTheme.lightTheme(),
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
