import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/app_settings.dart';
import 'package:vma_running/calculator/running_calculator_draft.dart';
import 'package:vma_running/calculator/running_calculator_page.dart';
import 'package:vma_running/vma_home.dart';
import 'package:vma_running/widgets/number_wheel_picker.dart';
import 'package:vma_running/widgets/vma_celebration_overlay.dart';

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

String _display(WidgetTester tester, int index) => tester
    .widget<Text>(find.byKey(ValueKey('calculator-display-$index')))
    .data!;

Future<void> _edit(
  WidgetTester tester, {
  required int index,
  required String selected,
  required String input,
}) async {
  await tester.ensureVisible(find.byKey(ValueKey('calculator-value-$index')));
  await tester.tap(find.byKey(ValueKey('calculator-value-$index')));
  await tester.pumpAndSettle();
  await tester.tap(
    find
        .descendant(
          of: find.byType(NumberValueWheelPicker),
          matching: find.text(selected),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, input);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compact selectors carry units while value tiles stay clear', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var draft = const RunningCalculatorDraft();
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => RunningCalculatorPage(
            draft: draft,
            vma: 18,
            onVmaChanged: (_) {},
            onChanged: (value) => setState(() => draft = value),
          ),
        ),
      ),
    );

    expect(find.text('Input'), findsNWidgets(2));
    expect(find.text('Calculated'), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(Card),
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsNothing,
    );
    final selector = find.byKey(
      const ValueKey('calculator-measure-0-distance'),
    );
    final value = find.byKey(const ValueKey('calculator-value-0'));
    expect(
      tester.getSize(selector).height,
      lessThan(tester.getSize(value).height),
    );
    expect(
      find.descendant(of: value, matching: find.textContaining('km')),
      findsNothing,
    );
    final decorator = tester.widget<InputDecorator>(
      find.descendant(of: value, matching: find.byType(InputDecorator)),
    );
    expect(decorator.decoration.labelText, isNull);
    final valueSemantics = tester.getSemantics(
      find.bySemanticsLabel('Distance (km), Input'),
    );
    expect(valueSemantics.value, '5');
    expect(
      valueSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Intensity (% VMA)').last);
    await tester.pumpAndSettle();
    expect(draft.first, RunningMeasure.intensity);
    expect(_display(tester, 0), '100');
    expect(find.bySemanticsLabel('Intensity (% VMA), Input'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'wheel typing updates calculations and preserves comma decimals',
    (tester) async {
      var draft = const RunningCalculatorDraft();
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => RunningCalculatorPage(
              draft: draft,
              vma: 18,
              onVmaChanged: (_) {},
              onChanged: (value) => setState(() => draft = value),
            ),
          ),
        ),
      );
      expect(_display(tester, 2), '12.00');
      expect(find.text('Calculator'), findsNothing);
      expect(find.textContaining('Choose four'), findsNothing);
      await _edit(tester, index: 0, selected: '5', input: '2,5');
      expect(_display(tester, 0), '2.5');
      expect(_display(tester, 2), '6.00');
      expect(_display(tester, 3), '10:00');
      expect(draft.inputIndices, [0, 1]);
    },
  );

  testWidgets('custom distance and fractional duration stay exact', (
    tester,
  ) async {
    var draft = const RunningCalculatorDraft();
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => RunningCalculatorPage(
            draft: draft,
            vma: 18,
            onVmaChanged: (_) {},
            onChanged: (value) => setState(() => draft = value),
          ),
        ),
      ),
    );
    await _edit(tester, index: 0, selected: '5', input: '5.12345');
    expect(double.parse(draft.firstText), closeTo(5.12345, 1e-12));
    await _edit(tester, index: 1, selected: '25:00', input: '1500.25');
    expect(parseRunningValue(RunningMeasure.time, draft.secondText), 1500.25);
    expect(draft.calculate(18)!.seconds, 1500.25);
  });

  testWidgets('editing calculated pace replaces the speed-family input', (
    tester,
  ) async {
    var draft = const RunningCalculatorDraft(
      inputIndices: [0, 2],
      thirdText: '12',
    );
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => RunningCalculatorPage(
            draft: draft,
            vma: 18,
            onVmaChanged: (_) {},
            onChanged: (value) => setState(() => draft = value),
          ),
        ),
      ),
    );
    await _edit(tester, index: 3, selected: '05:00', input: '4:00');
    expect(draft.inputIndices, [0, 3]);
    expect(_display(tester, 1), '20:00');
    expect(_display(tester, 2), '15.00');
  });

  testWidgets('intensity uses calculator VMA and follows supplied updates', (
    tester,
  ) async {
    var draft = const RunningCalculatorDraft(
      second: RunningMeasure.intensity,
      secondText: '100',
    );
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
              onVmaChanged: (value) => setState(() => vma = value),
              onChanged: (value) => setState(() => draft = value),
            );
          },
        ),
      ),
    );
    expect(_display(tester, 2), '18.00');
    await _edit(tester, index: 1, selected: '100', input: '87.5');
    expect(_display(tester, 2), '15.75');
    change(() => vma = 20);
    await tester.pump();
    expect(_display(tester, 2), '17.50');
    change(() => vma = null);
    await tester.pump();
    expect(_display(tester, 2), '');
    expect(find.text('Set your VMA to calculate intensity.'), findsOneWidget);
  });

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
                onVmaChanged: (_) {},
              ),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('calculator draft and local VMA survive switching tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'user_vma': 18.0});
    PackageInfo.setMockInitialValues(
      appName: 'VMA',
      packageName: 'vma_running',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await tester.pumpWidget(
      _app(
        VmaHomePage(settings: const AppSettings(), onSettingsChanged: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pumpAndSettle();
    await _edit(tester, index: 0, selected: '5', input: '10');
    expect(_display(tester, 2), '24.00');

    await tester.tap(find.byKey(const ValueKey('calculator-vma')));
    await tester.pumpAndSettle();
    final whole = find.byKey(const ValueKey('number-whole-picker'));
    await tester.tap(
      find.descendant(of: whole, matching: find.text('18')).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('VMA: 20.00 km/h'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getDouble('user_vma'), 18);
    expect(find.byType(VmaCelebrationOverlay), findsNothing);

    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.calculate_outlined));
    await tester.pumpAndSettle();
    expect(_display(tester, 2), '24.00');
    expect(_display(tester, 0), '10');
    expect(find.text('VMA: 20.00 km/h'), findsOneWidget);

    // Updating the saved VMA in settings provides the calculator's new default.
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vma-edit')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: whole, matching: find.text('18')).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '21');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(preferences.getDouble('user_vma'), 21);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('VMA: 21.00 km/h'), findsOneWidget);
    expect(_display(tester, 0), '10');
  });
}
