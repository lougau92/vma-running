import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/coros/coros_export.dart';
import 'package:vma_running/coros/coros_export_flow.dart';
import 'package:vma_running/watch/watch_export_dialog.dart';
import 'package:vma_running/watch/watch_provider.dart';
import 'package:vma_running/watch/watch_service_client.dart';
import 'package:vma_running/watch/watch_workout.dart';

import 'garmin_client_test.dart' show TestSession;
import 'garmin_ui_test.dart' show app, session, tap;

final strings = AppLocalizations(const Locale('en'));

const warmup = ResolvedWatchStep('warmup', 'warmup', 'time', 60, null, null, [
  'Warm up gently.',
]);
const interval = ResolvedWatchStep(
  'main',
  'interval',
  'distance',
  200,
  1000 / 270,
  4,
  [],
);
const recovery = ResolvedWatchStep('main', 'recovery', 'time', 30, null, null, [
  'Jog easily.',
]);
const cooldown = ResolvedWatchStep(
  'cooldown',
  'cooldown',
  'manual',
  null,
  null,
  null,
  [],
);

CorosExport export(List<ResolvedWatchNode> nodes) => buildCorosExport(
  ResolvedWatchWorkout('VMA export test', '', nodes, [], [], []),
  strings,
);

void main() {
  test(
    'encodes the live COROS workout format and keeps recovery between sets',
    () {
      final result = export([
        warmup,
        const ResolvedWatchRepeat(3, [interval], [recovery]),
        cooldown,
      ]);
      expect(result.problems, isEmpty);
      expect(result.course['sportType'], 1);
      expect(
        result.course['courseDescription'],
        'Warm up gently.\nJog easily.',
      );
      const work = {
        'sectionType': 2,
        'targetType': 1,
        'targetValue': 200,
        'intensityType': 2,
        'intensityValueStart': 250,
        'intensityValueEnd': 270,
      };
      expect(result.course['sections'], [
        {'sectionType': 1, 'targetType': 2, 'targetValue': 60},
        {
          'intervalGroup': true,
          'repeats': 2,
          'sets': [
            work,
            {'sectionType': 3, 'targetType': 2, 'targetValue': 30},
          ],
        },
        work,
        {'sectionType': 4, 'targetType': 4},
      ]);
    },
  );

  test('expands nested repeats without adding a final between-block pause', () {
    final result = export([
      const ResolvedWatchRepeat(
        2,
        [
          ResolvedWatchRepeat(2, [interval], []),
        ],
        [recovery],
      ),
    ]);
    expect(result.problems, isEmpty);
    final sections = result.course['sections'] as List<Map<String, dynamic>>;
    expect(sections[0]['repeats'], 2);
    expect(sections[1]['sectionType'], 3);
    expect(sections[2]['repeats'], 2);
    expect(sections, hasLength(3));
  });

  test('descriptive end remains an instruction and blocks saving', () {
    final result = export([
      const ResolvedWatchStep(
        'warmup',
        'warmup',
        'descriptive',
        null,
        null,
        null,
        ['Warm up along the marked route.'],
      ),
    ]);
    expect(result.problems, contains(strings['coros_end_unsupported']));
    expect(
      result.course['courseDescription'],
      'Warm up along the marked route.',
    );
  });
  testWidgets('sends the previewed course and reuses the key after a timeout', (
    tester,
  ) async {
    final keys = <String?>[];
    final client = WatchServiceClient(
      baseUrl: 'https://watch.example',
      session: TestSession(),
      httpClient: MockClient((request) async {
        if (request.url.path == '/coros/status') {
          return http.Response('{"connectionId":"current"}', 200);
        }
        expect(request.url.path, '/coros/workouts');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['connectionId'], 'current');
        final sections = payload['course']['sections'] as List;
        expect(sections.first['targetType'], 4);
        expect(sections[1]['sets'][0]['intensityValueStart'], 225);
        keys.add(request.headers['Idempotency-Key']);
        if (keys.length == 1) throw http.ClientException('timed out');
        return http.Response('{"workoutId":"90071992547409939"}', 200);
      }),
    );
    addTearDown(client.close);
    final workout = session();
    await tester.pumpWidget(
      app(
        WatchExportDialog(
          flow: CorosExportFlow(client),
          workout: WatchExportRequest(workout, workout.versions.single, 16, []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Save to COROS');
    await tap(tester, 'Save to COROS');
    expect(keys, hasLength(2));
    expect(keys.first, isNotEmpty);
    expect(keys.first, keys.last);
    expect(find.textContaining('Send to Device'), findsOneWidget);
  });
}
