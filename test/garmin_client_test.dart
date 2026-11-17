import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vma_running/firebase_content_session.dart';
import 'package:vma_running/garmin/garmin_client.dart';
import 'package:vma_running/garmin/garmin_journal.dart';

class TestSession extends FirebaseContentSession {
  TestSession([this.uid = 'anonymous-a']);
  final String uid;
  final refreshes = <bool>[];
  @override
  Future<String> idToken({bool forceRefresh = false}) async {
    refreshes.add(forceRefresh);
    return forceRefresh ? 'refreshed' : 'original';
  }

  @override
  Future<String> userId() async => uid;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test(
    'refreshes once on 401, uses same identity and whitelisted request headers',
    () async {
      final session = TestSession();
      var count = 0;
      final client = GarminClient(
        baseUrl: 'https://proxy.example',
        session: session,
        httpClient: MockClient((request) async {
          count++;
          expect(request.headers.containsKey('Cache-Control'), false);
          if (count == 1) {
            return http.Response('{"error":"firebase_token_required"}', 401);
          }
          expect(request.headers['Authorization'], 'Bearer refreshed');
          return http.Response('{"connected":true}', 200);
        }),
      );
      expect(await client.status(), true);
      expect(session.refreshes, [false, true]);
    },
  );
  test('rejects unconfigured, insecure or credential-bearing endpoint', () {
    for (final url in [
      '',
      'http://proxy.example',
      'https://user:password@proxy.example',
      'https://proxy.example?x=y',
    ]) {
      expect(GarminClient(baseUrl: url).configured, false);
    }
    expect(GarminClient(baseUrl: 'http://localhost:8080').configured, true);
  });
  test(
    'MFA parses opaque challenge; failures do not expose upstream bodies',
    () async {
      final client = GarminClient(
        baseUrl: 'https://proxy.example',
        session: TestSession(),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return http.Response(
              '{"status":"mfa_required","challengeId":"opaque-challenge"}',
              200,
            );
          }
          return http.Response('upstream password=secret', 500);
        }),
      );
      expect(
        (await client.login('a@b.com', 'secret')).challenge,
        'opaque-challenge',
      );
      await expectLater(
        client.mfa('opaque-challenge', '123456'),
        throwsA(
          isA<GarminFailure>().having(
            (e) => e.toString(),
            'safe error',
            isNot(contains('secret')),
          ),
        ),
      );
    },
  );
  test('durable operation retry reuses key, scoped by Firebase UID', () async {
    final keys = <String?>[];
    var fail = true;
    final client = GarminClient(
      baseUrl: 'https://proxy.example',
      session: TestSession(),
      httpClient: MockClient((request) async {
        keys.add(request.headers['Idempotency-Key']);
        if (fail) return http.Response('{"error":"garmin_unavailable"}', 502);
        return http.Response('{"workoutId":123,"replayed":true}', 200);
      }),
    );
    final journal = GarminJournal(client);
    final operation = await journal.prepare({'workoutName': 'Test'});
    await expectLater(journal.upload(operation), throwsA(isA<GarminFailure>()));
    fail = false;
    final restored = await GarminJournal(
      client,
    ).prepare({'workoutName': 'Test'});
    await journal.upload(restored);
    expect(keys, [operation.key, operation.key]);
    expect((await journal.load()).single.workoutId, 123);
    expect((await journal.prepare({'workoutName': 'Test'})).key, operation.key);
    expect(
      (await journal.prepare({'workoutName': 'Test'}, anotherCopy: true)).key,
      isNot(operation.key),
    );
    final other = GarminJournal(
      GarminClient(session: TestSession('anonymous-b')),
    );
    expect(await other.load(), isEmpty);
  });
  test(
    'failed watch delivery never uploads and reuses its own durable key',
    () async {
      final requests = <http.Request>[];
      var fail = true;
      final client = GarminClient(
        baseUrl: 'https://proxy.example',
        session: TestSession(),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/send')) {
            return http.Response(
              fail
                  ? '{"error":"garmin_unavailable"}'
                  : '{"status":"delivery_requested"}',
              fail ? 502 : 200,
            );
          }
          return http.Response('{"workoutId":123}', 200);
        }),
      );
      final journal = GarminJournal(client);
      final op = await journal.prepare({'workoutName': 'Test'});
      await journal.upload(op);
      await expectLater(journal.send(op, 42), throwsA(isA<GarminFailure>()));
      fail = false;
      final restored = (await journal.load()).single;
      await journal.send(restored, 42);
      await journal.send(restored, 42);
      expect(requests.length, 3);
      expect(
        requests[1].headers['Idempotency-Key'],
        requests[2].headers['Idempotency-Key'],
      );
      expect(
        requests[0].headers['Idempotency-Key'],
        isNot(requests[1].headers['Idempotency-Key']),
      );
      expect(jsonDecode(requests[2].body), {'deviceId': 42});
      expect((await journal.load()).single.delivered, [42]);
    },
  );
  test(
    'corrupt journal blocks requests instead of forgetting pending operations',
    () async {
      SharedPreferences.setMockInitialValues({
        'garmin_operations_v1_anonymous-a': 'broken',
      });
      await expectLater(
        GarminJournal(GarminClient(session: TestSession())).prepare({}),
        throwsA(isA<GarminFailure>()),
      );
    },
  );
}
