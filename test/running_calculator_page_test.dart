import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/app_settings.dart';
import 'package:vma_running/calculator/running_calculator_draft.dart';
import 'package:vma_running/calculator/running_calculator_page.dart';
import 'package:vma_running/vma_home.dart';

Widget _app(Widget child, {String locale = 'en'}) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

String _result(WidgetTester tester, String name) => tester
    .widget<SelectableText>(find.byKey(ValueKey('calculator-result-$name')))
    .data!;

void main() {
  testWidgets('updates live, clears stale results and accepts comma decimals', (
    tester,
  ) async {
    var draft = const RunningCalculatorDraft();
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => RunningCalculatorPage(
            draft: draft,
            vma: 18,
            onEditVma: () {},
            onChanged: (value) => setState(() => draft = value),
          ),
        ),
      ),
    );
    expect(_result(tester, 'speed'), '12.00');
    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.pump();
    expect(_result(tester, 'speed'), '24.00');
    expect(_result(tester, 'pace'), '02:30');
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.pump();
    expect(find.byType(SelectableText), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '2,5');
    await tester.pump();
    expect(_result(tester, 'speed'), '6.00');
    expect(_result(tester, 'intensity'), '33.33');
  });

  testWidgets(
    'supports pace and intensity inputs and filters dependent quantities',
    (tester) async {
      var draft = const RunningCalculatorDraft();
      double? vma = 18;
      late StateSetter change;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return RunningCalculatorPage(
                draft: draft,
                vma: vma,
                onEditVma: () {},
                onChanged: (value) => setState(() => draft = value),
              );
            },
          ),
        ),
      );
      await tester.tap(
        find.byType(DropdownButtonFormField<RunningMeasure>).at(1),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pace (min:sec/km)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '4:00');
      await tester.pump();
      expect(_result(tester, 'time'), '20:00');
      expect(_result(tester, 'speed'), '15.00');
      final first = tester.widget<DropdownButton<RunningMeasure>>(
        find.descendant(
          of: find.byType(DropdownButtonFormField<RunningMeasure>).first,
          matching: find.byType(DropdownButton<RunningMeasure>),
        ),
      );
      expect(first.items!.map((item) => item.value), [
        RunningMeasure.distance,
        RunningMeasure.time,
      ]);
      change(() => draft = draft.select(1, RunningMeasure.intensity));
      await tester.pump();
      expect(_result(tester, 'speed'), '18.00');
      change(() => vma = 20);
      await tester.pump();
      expect(_result(tester, 'speed'), '20.00');
      change(() => vma = null);
      await tester.pump();
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('Set your VMA to calculate intensity.'), findsOneWidget);
    },
  );

  for (final locale in ['en', 'fr', 'nl']) {
    testWidgets('fits a narrow screen with large text in $locale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: RunningCalculatorPage(
                draft: const RunningCalculatorDraft(),
                vma: null,
                onChanged: (_) {},
                onEditVma: () {},
              ),
            ),
          ),
          locale: locale,
        ),
      );
      expect(_result(tester, 'intensity'), '—');
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('calculator draft survives switching tabs', (tester) async {
    SharedPreferences.setMockInitialValues({'user_vma': 18.0});
    await tester.pumpWidget(
      _app(
        VmaHomePage(settings: const AppSettings(), onSettingsChanged: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.pump();
    expect(_result(tester, 'speed'), '24.00');
    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pumpAndSettle();
    expect(_result(tester, 'speed'), '24.00');
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .initialValue,
      '10',
    );
  });
}
