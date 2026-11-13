import 'dart:async' show StreamController, TimeoutException, unawaited;
import 'dart:convert' show jsonEncode;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/app_localizations.dart' show AppLocalizations;
import 'package:vma_running/app_settings.dart' show AppSettings;
import 'package:vma_running/club_communications_page.dart'
    show ClubCommunicationsPage;
import 'package:vma_running/remote_asset_loader.dart'
    show RemoteAssetLoader, RemoteLoadOrigin, RemoteLoadResult;
import 'package:vma_running/vma_challenge_table.dart' show VmaChallengeTable;
import 'package:vma_running/vma_training_plan.dart' show VmaTrainingPlan;

class _Loader extends RemoteAssetLoader {
  final updates = StreamController<RemoteLoadResult>();
  final refreshed = StreamController<RemoteLoadResult>();
  bool _opened = false;
  int refreshes = 0;

  @override
  Stream<RemoteLoadResult> watchText({
    required String documentPath,
    required String assetPath,
    String fieldName = 'content',
    void Function(String)? validate,
  }) {
    if (!_opened) {
      _opened = true;
      return updates.stream;
    }
    refreshes++;
    return refreshed.stream;
  }
}

String _plan(String label, int groups) => jsonEncode({
  'title': 'Plan',
  'warmup': label,
  'cooldown': 'Cool down',
  'remarks': '',
  'groups': List.generate(
    groups,
    (i) => {'title': 'Group ${i + 1}', 'blocks': []},
  ),
});

Widget _screen(int kind, _Loader loader) => switch (kind) {
  0 => VmaTrainingPlan(
    userVma: 18,
    settings: const AppSettings(),
    onSettingsChanged: (_) {},
    loader: loader,
  ),
  1 => VmaChallengeTable(loader: loader),
  _ => ClubCommunicationsPage(loader: loader),
};

String _data(int kind, String label) => switch (kind) {
  0 => _plan(label, label == 'Saved content' ? 2 : 1),
  1 => 'Name,Total\n$label,10',
  _ => jsonEncode({
    'version': 1,
    'messages': [],
    'keyCheck': '',
    'passwordHint': label,
  }),
};

void main() {
  for (var kind = 0; kind < 3; kind++) {
    testWidgets(
      '${['training plan', 'challenge', 'communications'][kind]} displays local data and keeps it during desktop refresh',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final loader = _Loader();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: _screen(kind, loader)),
          ),
        );
        loader.updates.add(
          RemoteLoadResult(
            data: _data(kind, 'Saved content'),
            origin: RemoteLoadOrigin.cache,
            refreshing: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.textContaining('Saved content'), findsOneWidget);
        if (kind == 0) {
          await tester.tap(find.text('Group 2'));
          await tester.pump();
          expect(
            tester
                .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
                .selected,
            {1},
          );
        }
        loader.updates.add(
          RemoteLoadResult(
            data: _data(kind, 'Saved content'),
            origin: RemoteLoadOrigin.cache,
            error: TimeoutException('offline'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.refresh),
              )
              .onPressed,
          isNotNull,
          reason:
              'the stream may remain open for a late response after timeout',
        );
        loader.updates.add(
          RemoteLoadResult(
            data: _data(kind, 'Fresh content'),
            origin: RemoteLoadOrigin.network,
          ),
        );
        unawaited(loader.updates.close());
        await tester.pumpAndSettle();
        expect(find.textContaining('Fresh content'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'the fresh plan can have fewer groups',
        );

        await tester.tap(find.byTooltip('Refresh content'));
        await tester.pump();
        await tester.pump();
        expect(loader.refreshes, 1);
        expect(
          find.textContaining('Fresh content'),
          findsOneWidget,
          reason: 'refresh must not replace usable data with a loading screen',
        );
        loader.refreshed.add(
          RemoteLoadResult(
            data: _data(kind, 'Fresh content'),
            origin: RemoteLoadOrigin.cache,
            error: StateError('offline'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Fresh content'), findsOneWidget);
        loader.refreshed.add(
          RemoteLoadResult(
            data: _data(kind, 'Recovered content'),
            origin: RemoteLoadOrigin.network,
          ),
        );
        unawaited(loader.refreshed.close());
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Recovered content'),
          findsOneWidget,
          reason: 'manual refresh must continue accepting late recovery',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({TargetPlatform.linux}),
    );
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets(
        '$kind hides mobile refresh on $platform and retains pull-to-refresh',
        (tester) async {
          // A tablet-sized viewport still uses mobile interaction.
          await tester.binding.setSurfaceSize(const Size(1024, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final loader = _Loader();
          await tester.pumpWidget(
            MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(body: _screen(kind, loader)),
            ),
          );
          loader.updates.add(
            RemoteLoadResult(
              data: _data(kind, 'Saved content'),
              origin: RemoteLoadOrigin.cache,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byTooltip('Refresh content'), findsNothing);
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 400),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(loader.refreshes, 1);
          loader.refreshed.add(
            RemoteLoadResult(
              data: _data(kind, 'Recovered content'),
              origin: RemoteLoadOrigin.network,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('Recovered content'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          unawaited(loader.updates.close());
          unawaited(loader.refreshed.close());
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
