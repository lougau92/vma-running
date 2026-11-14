import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/app_settings.dart';
import 'package:vma_running/running/running.dart';
import 'package:vma_running/settings_storage.dart';
import 'package:vma_running/vma_home.dart';
import 'package:vma_running/vma_times_table.dart';

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

List<String> _firstColumn(WidgetTester tester) => tester
    .widget<DataTable>(find.byType(DataTable))
    .rows
    .map(
      (row) =>
          (((row.cells.first.child as SizedBox).child as Center).child as Text)
              .data!,
    )
    .toList();

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'user_vma': 15.0}));

  test(
    'settings round-trip precise custom rows and preserve other choices',
    () async {
      final storage = SettingsStorage();
      expect((await storage.load()).timesCustomDistances, isEmpty);
      final original = const AppSettings(
        localeCode: 'nl',
        themeMode: ThemeMode.dark,
        themeId: 'lagoon',
        timesMinDistance: 137.25,
        timesMaxDistance: 875,
        timesMinSeconds: 61.25,
        timesMaxSeconds: 3600,
        timesCustomDistances: [875, 137.25, 875],
        timesCustomSeconds: [61.25, 137.5],
      );
      await storage.save(original);
      final loaded = await storage.load();
      expect(loaded.timesCustomDistances, [137.25, 875]);
      expect(loaded.timesCustomSeconds, [61.25, 137.5]);
      expect(loaded.timesMinDistance, 137.25);
      expect(loaded.timesMaxDistance, 875);
      final reset = loaded.copyWith(timesCustomDistances: []);
      await storage.save(reset);
      final reloaded = await storage.load();
      expect(reloaded.timesCustomDistances, isEmpty);
      expect(reloaded.timesCustomSeconds, [61.25, 137.5]);
      expect(reloaded.localeCode, 'nl');
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.themeId, 'lagoon');
      expect(reloaded.timesMinSeconds, 61.25);
    },
  );

  test('invalid saved custom entries are ignored', () async {
    SharedPreferences.setMockInitialValues({
      'times_custom_distances': [
        '137.25',
        '-1',
        'NaN',
        'Infinity',
        'bad',
        '137.25',
      ],
      'times_custom_seconds': ['0', '61.5'],
    });
    final settings = await SettingsStorage().load();
    expect(settings.timesCustomDistances, [137.25]);
    expect(settings.timesCustomSeconds, [61.5]);
  });

  testWidgets(
    'custom rows merge with presets, deduplicate and survive range filtering',
    (tester) async {
      Widget table({double max = 1000}) => _app(
        VmaTimesTable(
          speed: RunningSpeed.fromKmh(15),
          minDistanceMeters: 100,
          maxDistanceMeters: max,
          minTimeSeconds: 60,
          maxTimeSeconds: 300,
          customDistances: const [875, 137, 100, 137, 2000],
          customTimes: const [137, 137, 300],
          onEditDistances: () {},
          onEditTimes: () {},
        ),
      );
      await tester.pumpWidget(table());
      expect(_firstColumn(tester), [
        '100 m',
        '137 m',
        '200 m',
        '300 m',
        '400 m',
        '500 m',
        '875 m',
        '1 km',
      ]);
      await tester.pumpWidget(table(max: 2000));
      expect(_firstColumn(tester).last, '2 km');
      expect(
        _firstColumn(tester).where((text) => text == '2 km'),
        hasLength(1),
      );
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pump();
      expect(_firstColumn(tester), ['01:00', '02:17', '05:00']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Chronos restores saved custom rows and reset clears only distance rows',
    (tester) async {
      var settings = const AppSettings(
        localeCode: 'en',
        themeId: 'lagoon',
        timesMinDistance: 137,
        timesMaxDistance: 875,
        timesMinSeconds: 60,
        timesMaxSeconds: 300,
        timesCustomDistances: [137, 875],
        timesCustomSeconds: [137],
      );
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => VmaHomePage(
              settings: settings,
              onSettingsChanged: (value) => setState(() => settings = value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.timer));
      await tester.pumpAndSettle();
      expect(_firstColumn(tester).first, '137 m');
      expect(_firstColumn(tester).last, '875 m');
      await tester.tap(find.text('Distance'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('reset-custom-rows')),
      );
      await tester.tap(find.byKey(const ValueKey('reset-custom-rows')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(settings.timesCustomDistances, isEmpty);
      expect(settings.timesCustomSeconds, [137]);
      expect(settings.themeId, 'lagoon');
      expect(settings.timesMinDistance, 100);
      expect(settings.timesMaxDistance, 1000);
      expect(settings.timesMinSeconds, 60);
      expect(_firstColumn(tester).first, '100 m');
      expect(_firstColumn(tester).last, '1 km');
      expect(tester.takeException(), isNull);
    },
  );
}
