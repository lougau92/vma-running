import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/presets.dart';
import 'package:vma_running/vma_times_settings_dialog.dart';

Widget _app(Future<void> Function(BuildContext) edit) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: Builder(
      builder: (context) =>
          TextButton(onPressed: () => edit(context), child: const Text('Edit')),
    ),
  ),
);

CupertinoPicker _picker(WidgetTester tester, String key) =>
    tester.widget<CupertinoPicker>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(CupertinoPicker),
      ),
    );

void main() {
  testWidgets('distance bounds use wheels and reject reversed bounds', (
    tester,
  ) async {
    DistanceRange? result;
    await tester.pumpWidget(
      _app((context) async {
        result = await showDistancesSettingsDialog(
          context,
          initialMin: 100,
          initialMax: 1000,
        );
      }),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final min = _picker(tester, 'range-min-picker').scrollController!;
    min.jumpToItem(presetDistances().indexOf(2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
      find.text(AppLocalizations(const Locale('en')).minLessThanMax),
      findsOneWidget,
    );
    min.jumpToItem(presetDistances().indexOf(500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result!.min, 500);
    expect(result!.max, 1000);
  });

  testWidgets('custom initial distance bounds survive unchanged Save', (
    tester,
  ) async {
    DistanceRange? result;
    await tester.pumpWidget(
      _app((context) async {
        result = await showDistancesSettingsDialog(
          context,
          initialMin: 125,
          initialMax: 875,
        );
      }),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result!.min, 125);
    expect(result!.max, 875);
  });

  testWidgets('time bounds return seconds and Cancel discards wheel changes', (
    tester,
  ) async {
    TimeRange? result;
    await tester.pumpWidget(
      _app((context) async {
        result = await showTimesSettingsDialog(
          context,
          initialMinSeconds: 60,
          initialMaxSeconds: 3600,
        );
      }),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    _picker(tester, 'range-min-picker').scrollController!.jumpToItem(1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(
      _picker(tester, 'range-min-picker').scrollController!.selectedItem,
      0,
    );
    _picker(tester, 'range-min-picker').scrollController!.jumpToItem(1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result!.minSeconds, 300);
    expect(result!.maxSeconds, 3600);
    expect(tester.takeException(), isNull);
  });
}
