import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/garmin/garmin_client.dart';
import 'package:vma_running/garmin/garmin_connection.dart';
import 'package:vma_running/garmin/garmin_export_flow.dart';
import 'package:vma_running/theme.dart';
import 'package:vma_running/watch/watch_export_dialog.dart';
import 'package:vma_running/watch/watch_provider.dart';
import 'package:vma_running/workouts/workout.dart';

import 'garmin_client_test.dart' show TestSession;
import 'workout_fixture.dart';

class _Garmin extends GarminClient {
  _Garmin() : super(baseUrl: 'https://proxy.example', session: TestSession());
  bool connected = true, failSend = false, requireMfa = false;
  int uploads = 0, sends = 0;
  final sendKeys = <String>[];
  @override
  Future<bool> status() async => connected;
  @override
  Future<GarminLogin> login(String email, String password) async => GarminLogin(
    requireMfa
        ? {'status': 'mfa_required', 'challengeId': 'opaque'}
        : {'status': 'connected'},
  );
  @override
  Future<void> mfa(String challenge, String code) async {
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<GarminUpload> upload(Map<String, dynamic> payload, String key) async {
    uploads++;
    return GarminUpload({'workoutId': 123});
  }

  @override
  Future<List<GarminDevice>> devices() async => [
    GarminDevice({
      'deviceId': 42,
      'name': 'fenix',
      'runningWorkoutCapable': true,
    }),
  ];
  @override
  Future<void> send(int workoutId, int deviceId, String key) async {
    sends++;
    sendKeys.add(key);
    if (failSend) throw const GarminFailure('garmin_unavailable');
  }
}

Widget app(Widget home, {bool dark = false, String lang = 'en'}) => MaterialApp(
  locale: Locale(lang),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: dark ? AppThemes.all.first.dark : AppThemes.all.first.light,
  home: Scaffold(body: home),
);
WorkoutSession session() {
  final json = workoutFixture();
  (json['workouts'][0]['versions'][0]['warmup']['plan'] as Map)['end'] = {
    'kind': 'manual',
  };
  return WorkoutSession(json['workouts'][0] as Map<String, dynamic>);
}

Future<void> tap(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(finder.last);
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('connection supports MFA, clears password, and disconnects', (
    tester,
  ) async {
    final client = _Garmin()
      ..connected = false
      ..requireMfa = true;
    await tester.pumpWidget(app(GarminConnectionDialog(client: client)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'a@example.com');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tap(tester, 'Connect / sign in again');
    expect(find.text('Verification code'), findsOneWidget);
    expect(find.text('secret'), findsNothing);
    await tester.enterText(find.byType(TextField), '123456');
    await tap(tester, 'Connect / sign in again');
    expect(find.textContaining('Garmin session saved'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Garmin email'), findsOneWidget);
  });
  testWidgets(
    'save then failed watch delivery retries without another upload',
    (tester) async {
      final client = _Garmin()..failSend = true;
      final plan = session();
      await tester.pumpWidget(
        app(
          WatchExportDialog(
            workout: WatchExportRequest(plan, plan.versions.single, 16, []),
            flow: GarminExportFlow(client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Save to Garmin Connect');
      expect(client.uploads, 1);
      expect(find.text('Saved in Garmin Connect'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final choose = find.widgetWithText(OutlinedButton, 'Send to watch');
      await tester.ensureVisible(choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      await tap(tester, 'Send to watch');
      expect(client.sends, 1);
      client.failSend = false;
      await tap(tester, 'Send to watch');
      expect(client.uploads, 1);
      expect(client.sendKeys[0], client.sendKeys[1]);
      expect(find.textContaining('Delivery requested'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    },
  );
  for (final dark in [false, true]) {
    for (final lang in ['en', 'fr', 'nl']) {
      testWidgets('narrow export $lang ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final plan = session();
        await tester.pumpWidget(
          app(
            WatchExportDialog(
              workout: WatchExportRequest(plan, plan.versions.single, 16, []),
              flow: GarminExportFlow(_Garmin()),
            ),
            dark: dark,
            lang: lang,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
