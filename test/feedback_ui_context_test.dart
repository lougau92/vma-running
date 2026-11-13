import 'dart:convert' show jsonEncode;
import 'package:app_feedback/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/app_settings.dart';
import 'package:vma_running/remote_asset_loader.dart';
import 'package:vma_running/vma_home.dart';

class _Sender implements FeedbackSender {
  FeedbackSubmission? sent;
  @override
  Future<void> send(FeedbackSubmission feedback) async => sent = feedback;
}

class _Loader extends RemoteAssetLoader {
  @override
  Stream<RemoteLoadResult> watchText({
    required String documentPath,
    required String assetPath,
    String fieldName = 'content',
    void Function(String)? validate,
  }) => Stream.value(
    RemoteLoadResult(
      origin: RemoteLoadOrigin.cache,
      data: jsonEncode({
        'title': 'Private workout title',
        'warmup': 'Private coach instructions',
        'cooldown': '',
        'remarks': '',
        'groups': [
          {'title': 'Group 1', 'blocks': []},
          {'title': 'Group 2', 'blocks': []},
        ],
      }),
    ),
  );
}

Future<Map<String, Object?>> _send(WidgetTester tester, _Sender sender) async {
  await tester.tap(find.byIcon(Icons.feedback_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('feedback-message')),
    'Useful feedback',
  );
  final send = find.byKey(const ValueKey('feedback-send'));
  await tester.ensureVisible(send);
  await tester.tap(send);
  await tester.pumpAndSettle();
  return sender.sent!.uiContext!.toJson();
}

void main() {
  testWidgets('captures changed Times controls and nested workout selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'user_vma': 18.0});
    final sender = _Sender();
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
        home: VmaHomePage(
          settings: const AppSettings(),
          onSettingsChanged: (_) {},
          feedbackSender: sender,
          loader: _Loader(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.timer));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.drag(find.byType(Slider), const Offset(-60, 0));
    await tester.pumpAndSettle();
    var snapshot = await _send(tester, sender);
    final scopes = (snapshot['scopes'] as List).cast<Map>();
    expect(
      (scopes.singleWhere((s) => s['id'] == 'times-table')['state']
          as Map)['mode'],
      'time-first',
    );
    final state = scopes.singleWhere((s) => s['id'] == 'times')['state'] as Map;
    expect(state['vmaKmh'], 18);
    expect(state['intensityPercent'], isNot(100));
    final slider = (snapshot['controls'] as List).cast<Map>().singleWhere(
      (c) => c['type'] == 'slider',
    );
    expect(slider['value'], state['intensityPercent']);
    await tester.tap(find.byIcon(Icons.fitness_center));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group 2'));
    await tester.pumpAndSettle();
    snapshot = await _send(tester, sender);
    final workoutScopes = (snapshot['scopes'] as List).cast<Map>();
    expect(snapshot['screen'], 'training-plan');
    expect(
      workoutScopes.map((s) => s['id']),
      containsAll(['warmup', 'intervals', 'cooldown', 'notes']),
    );
    final workout = workoutScopes.singleWhere((s) => s['id'] == 'workout');
    expect(workout['path'], [
      'home',
      'training-plan',
      'workout-content',
      'workout',
    ]);
    expect((workout['state'] as Map)['selectedGroup'], 1);
    expect(
      (workoutScopes.singleWhere((s) => s['id'] == 'workout-content')['state']
          as Map)['source'],
      'cache',
    );
    expect(jsonEncode(snapshot), isNot(contains('Private')));
    expect(tester.takeException(), isNull);
  });
}
