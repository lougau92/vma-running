import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/previews/app_previews.dart';
import 'package:vma_running/previews/control_previews.dart';
import 'package:vma_running/previews/preview_catalog.dart';
import 'package:vma_running/previews/preview_support.dart';
import 'package:vma_running/previews/running_previews.dart';
import 'package:vma_running/previews/settings_previews.dart';
import 'package:vma_running/previews/workout_previews.dart';
import 'package:vma_running/theme.dart';
import 'package:vma_running/widgets/times_tab.dart';
import 'package:vma_running/widgets/number_wheel_picker.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1100, 900)]) {
    for (final scenario in previewScenarios) {
      testWidgets('${scenario.name} preview at ${size.width.toInt()}px', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(appPreviewWrapper(scenario.build()));
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.takeException(), isNull, reason: scenario.name);
      });
    }
  }

  for (final theme in AppThemes.all) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final locale in ['en', 'fr', 'nl']) {
        testWidgets(
          'settings large text ${theme.id} ${brightness.name} $locale',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(320, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              MaterialApp(
                locale: Locale(locale),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                theme: theme.light,
                darkTheme: theme.dark,
                themeMode: brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.6)),
                  child: child!,
                ),
                home: const Scaffold(body: Builder(builder: _settingsBody)),
              ),
            );
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('workout page switches between sessions and groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(appPreviewWrapper(workoutPagePreview()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.tap(find.text('Groupe 5'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Groupe 5'))
          .selected,
      isTrue,
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Footing de récupération').last);
    await tester.pumpAndSettle();
    expect(find.text('Footing de récupération'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('intensity control responds to slider input', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(appPreviewWrapper(intensityControlPreview()));
    await tester.pump(const Duration(milliseconds: 100));
    final before = tester.widget<Slider>(find.byType(Slider)).value;
    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Slider>(find.byType(Slider)).value,
      greaterThan(before),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('range preview resets custom distance rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(appPreviewWrapper(distanceRangeDialogPreview()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Ouvrir le réglage'));
    await tester.pumpAndSettle();
    var picker = tester.widget<NumberValueWheelPicker>(
      find.byKey(const ValueKey('range-min-picker')),
    );
    expect(picker.values, contains(1350));
    await tester.tap(find.byKey(const ValueKey('reset-custom-rows')));
    await tester.pumpAndSettle();
    picker = tester.widget<NumberValueWheelPicker>(
      find.byKey(const ValueKey('range-min-picker')),
    );
    expect(picker.values, isNot(contains(1350)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('intensity range preview shows invalid-range guidance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(appPreviewWrapper(intensityRangeDialogPreview()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Ouvrir le réglage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('60%'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '125');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(AlertDialog).last);
    expect(
      find.text(AppLocalizations.of(context).minLessThanMax),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings preview opens the actual VMA editor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(appPreviewWrapper(settingsPreview()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('vma-edit')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app workspace opens each core running tab', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(appPreviewWrapper(appWorkspacePreview()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.timer));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TimesTab), findsOneWidget);
    await tester.tap(find.byIcon(Icons.fitness_center));
    await tester.pumpAndSettle();
    expect(find.text('Séance de fractionné'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Widget _settingsBody(BuildContext context) => settingsPreview();
