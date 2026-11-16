import 'package:vma_running/theme.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/remote_asset_loader.dart';
import 'package:vma_running/widgets/training_plan_page.dart';
import 'workout_fixture.dart';
import 'dart:convert';

class _Loader extends RemoteAssetLoader {
  _Loader(this.content);
  String content;
  final updates = StreamController<RemoteLoadResult>();
  @override
  Stream<RemoteLoadResult> watchText({
    required String documentPath,
    String? assetPath,
    String fieldName = 'content',
    void Function(String)? validate,
  }) async* {
    expect(documentPath, 'app_documents/workout_plan');
    validate?.call(content);
    yield RemoteLoadResult(data: content, origin: RemoteLoadOrigin.cache);
    yield* updates.stream;
  }
}

Widget _app(
  _Loader loader,
  String locale,
  bool dark, {
  String? themeId,
  double textScale = 1,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  locale: Locale(locale),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: dark
      ? AppThemes.resolve(themeId ?? 'summit').dark
      : AppThemes.resolve(themeId ?? 'enjambee').light,
  home: Scaffold(body: TrainingPlanPage(userVma: 18, loader: loader)),
);
void main() {
  for (final theme in AppThemes.all) {
    for (final dark in [false, true]) {
      testWidgets(
        'narrow workout with large text in ${theme.id}${dark ? ' dark' : ' light'}',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final loader = _Loader(
            File('test/fixtures/workouts/all_features.json').readAsStringSync(),
          );
          await tester.pumpWidget(
            _app(loader, 'fr', dark, themeId: theme.id, textScale: 1.6),
          );
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -800),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          unawaited(loader.updates.close());
        },
      );
    }
  }

  for (final locale in ['en', 'fr', 'nl']) {
    for (final width in [320.0, 1100.0]) {
      testWidgets('all structures render in $locale at width $width', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final loader = _Loader(
          File('test/fixtures/workouts/all_features.json').readAsStringSync(),
        );
        await tester.pumpWidget(_app(loader, locale, width > 1000));
        await tester.pumpAndSettle();
        expect(find.text('Main block'), findsOneWidget);
        expect(find.text('Controlled sprint'), findsOneWidget);
        expect(find.text('Technique cue'), findsOneWidget);
        expect(find.textContaining('Technique cue clarified'), findsOneWidget);
        expect(find.textContaining('Return downhill'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
        await tester.pumpWidget(const SizedBox());
        unawaited(loader.updates.close());
      });
    }
  }
  testWidgets(
    'session selection and version reset survive smaller replacement',
    (tester) async {
      final d = workoutFixture(groups: 2);
      final second =
          workoutFixture(title: 'Second session')['workouts'][0]
              as Map<String, dynamic>;
      second['id'] = 'second';
      (d['workouts'] as List).add(second);
      final loader = _Loader(jsonEncode(d));
      await tester.pumpWidget(_app(loader, 'en', false));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Group 2'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Group 2'))
            .selected,
        isTrue,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second session').last);
      await tester.pumpAndSettle();
      expect(find.text('Group 2'), findsNothing);
      loader.updates.add(
        RemoteLoadResult(
          data: jsonEncode(workoutFixture(title: 'Replacement')),
          origin: RemoteLoadOrigin.network,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Replacement'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      unawaited(loader.updates.close());
    },
  );
  testWidgets('duplicate version labels remain independently selectable', (
    tester,
  ) async {
    final d = workoutFixture(groups: 2);
    final versions = d['workouts'][0]['versions'] as List;
    versions[1]['label'] = 'Group 1';
    versions[1]['warmup']['plan']['end']['description'] =
        'Second version warmup';
    final loader = _Loader(jsonEncode(d));
    await tester.pumpWidget(_app(loader, 'en', false));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Group 1').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Second version warmup'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Group 1').last)
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    unawaited(loader.updates.close());
  });
}
