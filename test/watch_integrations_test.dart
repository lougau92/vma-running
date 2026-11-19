import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vma_running/garmin/garmin_client.dart';
import 'package:vma_running/watch/watch_integrations.dart';

import 'garmin_client_test.dart' show TestSession;
import 'garmin_ui_test.dart' show app, session;

class _Provider extends WatchProvider {
  _Provider(this.id, this.name);
  @override
  final String id, name;
  bool enabled = true;

  @override
  Future<bool> connected() async => enabled;

  @override
  Future<List<String>> devices() async => ['$name Watch'];

  @override
  Future<void> manage(BuildContext context) async {
    enabled = false;
  }

  @override
  Future<void> preview(BuildContext context, WatchExportRequest workout) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$name preview'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close preview'),
            ),
          ],
        ),
      );
}

void main() {
  testWidgets('export remembers the first provider choice', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final first = _Provider('garmin', 'Garmin Connect');
    final additional = _Provider('example', 'Example');
    final client = GarminClient(
      baseUrl: 'https://watch.example',
      session: TestSession(),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/watch/providers');
        return http.Response(
          jsonEncode({
            'providers': [
              for (final id in ['garmin', 'example', 'unsupported'])
                {'id': id, 'saveWorkout': true, 'listDevices': true},
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);
    final integrations = WatchIntegrations(
      client,
      providers: [first, additional],
    );
    final workout = session();
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => showWatchExport(
                  context,
                  WatchExportRequest(workout, workout.versions.single, 16, []),
                  integrations: integrations,
                ),
                child: const Text('Open export'),
              ),
            ],
          ),
        ),
      ),
    );

    first.enabled = false;
    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
    expect(find.text('Default destination'), findsOneWidget);
    expect(find.text('Example'), findsOneWidget);
    expect(find.text('Garmin Connect'), findsNothing);
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(await integrations.defaultProvider(), isNull);

    first.enabled = true;
    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
    expect(find.text('Default destination'), findsOneWidget);
    expect(find.text('unsupported'), findsNothing);
    expect(await integrations.defaultProvider(), isNull);
    await tester.tap(find.text('Example'));
    await tester.pumpAndSettle();
    expect(await integrations.defaultProvider(), 'example');
    expect(find.text('Example preview'), findsOneWidget);
    expect(find.text('Change destination'), findsNothing);
    await tester.tap(find.text('Close preview'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
    expect(find.text('Example preview'), findsOneWidget);
    expect(find.text('Default destination'), findsNothing);
    await tester.tap(find.text('Close preview'));
    await tester.pumpAndSettle();

    additional.enabled = false;
    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
    expect(find.text('Watch integrations'), findsOneWidget);
    expect(
      find.textContaining('Your default destination is unavailable'),
      findsOneWidget,
    );
    expect(find.text('Garmin Connect preview'), findsNothing);
    expect(await integrations.defaultProvider(), 'example');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garmin Connect').last);
    await tester.pumpAndSettle();
    expect(await integrations.defaultProvider(), 'garmin');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
    expect(find.text('Garmin Connect preview'), findsOneWidget);
  });
}
