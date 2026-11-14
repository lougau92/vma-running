import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/presets.dart';
import 'package:vma_running/vma_distance_dialog.dart';
import 'package:vma_running/vma_settings_dialog.dart';
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

Finder _wheel(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(CupertinoPicker),
);
CupertinoPicker _picker(WidgetTester tester, String key) =>
    tester.widget<CupertinoPicker>(_wheel(key));
Future<void> _typeValue(WidgetTester tester, String key, String value) async {
  await tester.tapAt(tester.getCenter(_wheel(key)));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  await tester.enterText(find.byType(TextField), value);
  await tester.pumpAndSettle();
}

Future<void> _dismiss(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(800, 700), const Size(360, 800)]) {
    testWidgets('intensity wheels adapt to $size and apply without buttons', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      VmaTableSettings? result;
      VmaTableSettings? live;
      await tester.pumpWidget(
        _app((context) async {
          result = await showVmaSettingsDialog(
            context,
            initialSettings: const VmaTableSettings(
              minPercent: 60,
              maxPercent: 120,
              step: 5,
            ),
            onChanged: (value) => live = value,
          );
        }),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final min = find.byKey(const ValueKey('intensity-min-picker'));
      final max = find.byKey(const ValueKey('intensity-max-picker'));
      final step = find.byKey(const ValueKey('intensity-step-picker'));
      expect(tester.getTopLeft(min).dy, tester.getTopLeft(max).dy);
      if (size.width > 600) {
        expect(tester.getTopLeft(step).dy, tester.getTopLeft(min).dy);
      } else {
        expect(
          tester.getTopLeft(step).dy,
          greaterThan(tester.getBottomLeft(min).dy),
        );
      }
      _picker(tester, 'intensity-step-picker').scrollController!.jumpToItem(9);
      await tester.pumpAndSettle();
      expect(live!.step, 10);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      await _dismiss(tester);
      expect(result!.minPercent, 60);
      expect(result!.maxPercent, 120);
      expect(result!.step, 10);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'bottom intensity wheel remains editable above the mobile keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 668);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      VmaTableSettings? live;
      await tester.pumpWidget(
        _app((context) async {
          await showVmaSettingsDialog(
            context,
            initialSettings: const VmaTableSettings(
              minPercent: 60,
              maxPercent: 120,
              step: 5,
            ),
            onChanged: (value) => live = value,
          );
        }),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_wheel('intensity-step-picker'));
      await tester.tapAt(tester.getCenter(_wheel('intensity-step-picker')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(TextField)).bottom,
        lessThanOrEqualTo(668 - 280),
      );
      await tester.enterText(find.byType(TextField), '10');
      await tester.pumpAndSettle();
      expect(live!.step, 10);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid bounds retain last applied range until corrected', (
    tester,
  ) async {
    DistanceRange? result;
    DistanceRange? live;
    await tester.pumpWidget(
      _app((context) async {
        result = await showDistancesSettingsDialog(
          context,
          initialMin: 100,
          initialMax: 1000,
          onChanged: (value) => live = value,
        );
      }),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    _picker(
      tester,
      'range-min-picker',
    ).scrollController!.jumpToItem(presetDistances().indexOf(500));
    await tester.pumpAndSettle();
    expect(live!.min, 500);
    _picker(
      tester,
      'range-min-picker',
    ).scrollController!.jumpToItem(presetDistances().indexOf(2000));
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizations(const Locale('en')).minLessThanMax),
      findsOneWidget,
    );
    expect(live!.min, 500);
    await _dismiss(tester);
    expect(result!.min, 500);
    expect(result!.max, 1000);
  });

  testWidgets(
    'custom distance typing stays in the same dialog and is not snapped',
    (tester) async {
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
      await _typeValue(tester, 'range-min-picker', '137');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await _dismiss(tester);
      expect(result!.min, 137);
      expect(result!.max, 875);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('time typing returns exact seconds when dismissed', (
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
    await _typeValue(tester, 'range-min-picker', '02:17');
    await _dismiss(tester);
    expect(result!.minSeconds, 137);
    expect(result!.maxSeconds, 3600);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'target distance wheel accepts custom values and rejects invalid typing',
    (tester) async {
      double? result;
      double? live;
      final changes = <double>[];
      await tester.pumpWidget(
        _app((context) async {
          result = await showDistanceDialog(
            context,
            initialDistanceMeters: 400,
            onChanged: (value) {
              live = value;
              changes.add(value);
            },
          );
        }),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsOneWidget);
      await _typeValue(tester, 'target-distance-picker', '1234.5');
      expect(live, 1234.5);
      expect(changes, [1234.5]);
      await tester.enterText(find.byType(TextField), '-2');
      await tester.pumpAndSettle();
      expect(live, 1234.5);
      expect(
        find.text(AppLocalizations(const Locale('en')).enterNumber),
        findsOneWidget,
      );
      await tester.tap(
        find.text(AppLocalizations(const Locale('en')).setTargetDistance),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(changes, [1234.5]);
      await tester.drag(_wheel('target-distance-picker'), const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(live, 1500);
      await _dismiss(tester);
      expect(result, 1500);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only completed manual values are remembered, including route dismissal',
    (tester) async {
      final remembered = <double>[];
      DistanceRange? live;
      await tester.pumpWidget(
        _app((context) async {
          await showDistancesSettingsDialog(
            context,
            initialMin: 100,
            initialMax: 1000,
            onChanged: (value) => live = value,
            onCustomValueAdded: remembered.add,
          );
        }),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await _typeValue(tester, 'range-min-picker', '1');
      await tester.enterText(find.byType(TextField), '13');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '137');
      await tester.pumpAndSettle();
      expect(live!.min, 137);
      expect(remembered, isEmpty);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(remembered, [137]);
      await _typeValue(tester, 'range-max-picker', '0.875');
      expect(live!.max, 875);
      expect(remembered, [137]);
      await tester.tap(
        find.text(AppLocalizations(const Locale('en')).distanceRange),
      );
      await tester.pumpAndSettle();
      expect(remembered, [137, 875]);
      await _typeValue(tester, 'range-max-picker', '876 m');
      await _dismiss(tester);
      expect(remembered, [137, 875, 876]);
      expect(tester.takeException(), isNull);
    },
  );
}
