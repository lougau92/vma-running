import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/vma_storage.dart';

Widget _app({double? initial, ValueChanged<double?>? onResult}) => MaterialApp(
  locale: const Locale('fr'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData.dark(),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final result = await VmaStorage().promptForVma(
            context,
            initialValue: initial,
          );
          onResult?.call(result);
        },
        child: const Text('Edit'),
      ),
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
  setUp(() => SharedPreferences.setMockInitialValues({'user_vma': 17.15}));

  testWidgets('scrolling preserves hundredths and only Save persists changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 668);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    double? result;
    await tester.pumpWidget(_app(initial: 17.15, onResult: (v) => result = v));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      _picker(tester, 'number-whole-picker').scrollController!.selectedItem,
      16,
    );
    expect(
      _picker(tester, 'number-fraction-picker').scrollController!.selectedItem,
      15,
    );

    await tester.drag(
      find.byKey(const ValueKey('number-fraction-picker')),
      const Offset(0, -40),
    );
    await tester.pumpAndSettle();
    expect(
      _picker(tester, 'number-fraction-picker').scrollController!.selectedItem,
      16,
    );
    expect(
      (await SharedPreferences.getInstance()).getDouble('user_vma'),
      17.15,
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(result, 17.16);
    expect(
      (await SharedPreferences.getInstance()).getDouble('user_vma'),
      17.16,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel discards the draft and reopening restores saved VMA', (
    tester,
  ) async {
    double? result = 99;
    await tester.pumpWidget(_app(initial: 17.15, onResult: (v) => result = v));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    _picker(tester, 'number-whole-picker').scrollController!.jumpToItem(20);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
      (await SharedPreferences.getInstance()).getDouble('user_vma'),
      17.15,
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(
      _picker(tester, 'number-whole-picker').scrollController!.selectedItem,
      16,
    );
    expect(
      _picker(tester, 'number-fraction-picker').scrollController!.selectedItem,
      15,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('first use offers a valid default without saving on dismissal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(
      _picker(tester, 'number-whole-picker').scrollController!.selectedItem,
      17,
    );
    expect(
      _picker(tester, 'number-fraction-picker').scrollController!.selectedItem,
      0,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await VmaStorage().load(), isNull);
  });
}
