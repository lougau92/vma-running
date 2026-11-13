import 'dart:convert' show jsonEncode;

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/app_settings.dart';
import 'package:vma_running/club_communications_page.dart';
import 'package:vma_running/feature_flags.dart';
import 'package:vma_running/remote_asset_loader.dart';
import 'package:vma_running/vma_challenge_table.dart';
import 'package:vma_running/vma_home.dart';
import 'package:vma_running/vma_times_table.dart';
import 'package:vma_running/vma_training_plan.dart';

class _Loader extends RemoteAssetLoader {
  final reads = <String>[];

  @override
  Stream<RemoteLoadResult> watchText({
    required String documentPath,
    required String assetPath,
    String fieldName = 'content',
    void Function(String)? validate,
  }) {
    reads.add(documentPath);
    final data = switch (documentPath) {
      'app_documents/challenge_classement' => 'Name,Total\nRunner,10',
      'app_documents/club_communications' => jsonEncode({
        'version': 1,
        'messages': [],
        'keyCheck': '',
        'passwordHint': 'Club hint',
      }),
      _ => jsonEncode({
        'title': 'Test workout',
        'warmup': 'Easy warmup',
        'cooldown': 'Easy cooldown',
        'remarks': '',
        'groups': [
          {'title': 'Group 1', 'blocks': []},
        ],
      }),
    };
    return Stream.value(
      RemoteLoadResult(data: data, origin: RemoteLoadOrigin.network),
    );
  }
}

Widget _app(_Loader loader, FeatureFlags flags) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: VmaHomePage(
    settings: const AppSettings(localeCode: 'en'),
    onSettingsChanged: (_) {},
    features: flags,
    loader: loader,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'user_vma': 18.0});
    PackageInfo.setMockInitialValues(
      appName: 'VMA',
      packageName: 'vma_running',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  for (final communications in [false, true]) {
    for (final rankings in [false, true]) {
      testWidgets(
        'tabs navigate correctly with communications=$communications rankings=$rankings',
        (tester) async {
          final loader = _Loader();
          await tester.pumpWidget(
            _app(
              loader,
              FeatureFlags(
                clubCommunications: communications,
                clubRankings: rankings,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final nav = tester.widget<BottomNavigationBar>(
            find.byType(BottomNavigationBar),
          );
          expect(
            nav.items.length,
            4 + (communications ? 1 : 0) + (rankings ? 1 : 0),
          );
          expect(
            find.byIcon(Icons.campaign_outlined),
            communications ? findsOneWidget : findsNothing,
          );
          expect(
            find.byIcon(Icons.emoji_events),
            rankings ? findsOneWidget : findsNothing,
          );
          expect(loader.reads, isEmpty);

          await tester.tap(find.byIcon(Icons.timer));
          await tester.pumpAndSettle();
          expect(find.byType(VmaTimesTable), findsOneWidget);
          await tester.tap(find.byIcon(Icons.fitness_center));
          await tester.pumpAndSettle();
          expect(find.byType(VmaTrainingPlan), findsOneWidget);
          expect(loader.reads, ['app_documents/training_plan']);

          if (communications) {
            await tester.tap(find.byIcon(Icons.campaign_outlined));
            await tester.pumpAndSettle();
            expect(find.byType(ClubCommunicationsPage), findsOneWidget);
          }
          if (rankings) {
            await tester.tap(find.byIcon(Icons.emoji_events));
            await tester.pumpAndSettle();
            expect(find.byType(VmaChallengeTable), findsOneWidget);
          }
          expect(
            loader.reads.contains('app_documents/club_communications'),
            communications,
          );
          expect(
            loader.reads.contains('app_documents/challenge_classement'),
            rankings,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'removing a preceding tab preserves selection and disabling the selected page returns home',
    (tester) async {
      final loader = _Loader();
      await tester.pumpWidget(
        _app(
          loader,
          const FeatureFlags(clubCommunications: true, clubRankings: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.emoji_events));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _app(
          loader,
          const FeatureFlags(clubCommunications: false, clubRankings: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VmaChallengeTable), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        4,
      );
      await tester.pumpWidget(
        _app(
          loader,
          const FeatureFlags(clubCommunications: false, clubRankings: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VmaChallengeTable), findsNothing);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('VMA settings update targets and persist after reopening', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Loader(), const FeatureFlags()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('vma-edit')), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(find.text('Intensity: 60%VMA'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vma-edit')));
    await tester.pumpAndSettle();
    final whole = tester.widget<CupertinoPicker>(
      find.descendant(
        of: find.byKey(const ValueKey('number-whole-picker')),
        matching: find.byType(CupertinoPicker),
      ),
    );
    whole.scrollController!.jumpToItem(19);
    final fraction = tester.widget<CupertinoPicker>(
      find.descendant(
        of: find.byKey(const ValueKey('number-fraction-picker')),
        matching: find.byType(CupertinoPicker),
      ),
    );
    fraction.scrollController!.jumpToItem(50);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('VMA: 20.50 km/h'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getDouble('user_vma'), 20.5);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('VMA: 20.50 km/h'), findsOneWidget);
    expect(
      tester.widget<VmaTimesTable>(find.byType(VmaTimesTable)).speed!.kmh,
      closeTo(12.3, 0.000001),
    );
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('VMA: 20.50 km/h'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'release defaults retain clipboard export and settings without integration controls',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final loader = _Loader();
      await tester.pumpWidget(_app(loader, const FeatureFlags()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.campaign_outlined), findsNothing);
      expect(find.byIcon(Icons.emoji_events), findsNothing);
      await tester.tap(find.byIcon(Icons.fitness_center));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Export'));
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(copied, contains('Easy warmup'));
      expect(copied, contains('Group 1'));
      expect(find.text('Plan copied to clipboard'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
