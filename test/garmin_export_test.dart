import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vma_running/app_localizations.dart';
import 'package:vma_running/garmin/garmin_export.dart';
import 'package:vma_running/workouts/workout.dart';

Map<String, dynamic> step({
  String role = 'effort',
  Map<String, dynamic>? end,
  List<Map<String, dynamic>> targets = const [],
  List<Map<String, dynamic>> notes = const [],
}) => {
  'kind': 'step',
  'role': role,
  'end':
      end ??
      {
        'kind': 'distance',
        'meters': {'min': 400, 'max': 400},
      },
  'targets': targets,
  'notes': notes,
};
Map<String, dynamic> time(int seconds) => {
  'kind': 'time',
  'seconds': {'min': seconds, 'max': seconds},
};
Map<String, dynamic> numeric(String metric, num min, num max) => {
  'kind': 'numeric',
  'metric': metric,
  'value': {'min': min, 'max': max},
};
GarminExport export(
  Map<String, dynamic> main, {
  Map<String, double> values = const {},
  bool defaultChoices = false,
  Map<String, dynamic>? warmup,
  Map<String, dynamic>? cooldown,
  double vma = 16,
}) {
  final session = WorkoutSession({
    'id': 'club',
    'title': 'Club workout',
    'notes': [
      {'text': 'Session note'},
    ],
    'versions': [
      {
        'label': 'Group 1',
        'notes': [
          {'text': 'Group note'},
        ],
        'warmup': warmup == null
            ? {'status': 'not_specified'}
            : {'status': 'specified', 'plan': warmup},
        'main': {'status': 'specified', 'plan': main},
        'cooldown': cooldown == null
            ? {'status': 'explicitly_none'}
            : {'status': 'specified', 'plan': cooldown},
      },
    ],
  });
  return buildGarminExport(
    session,
    session.versions.single,
    vma,
    AppLocalizations(const Locale('en')),
    values: values,
    defaultChoices: defaultChoices,
  );
}

List<Map<String, dynamic>> steps(GarminExport result) =>
    (((result.payload['workoutSegments'] as List).single as Map)['workoutSteps']
            as List)
        .cast<Map<String, dynamic>>();

void main() {
  test(
    'flattens nested repeats, maximum counts and only between recoveries',
    () {
      final result = export(
        {
          'kind': 'repeat',
          'count': {'min': 2, 'max': 3},
          'body': {
            'kind': 'repeat',
            'count': {'min': 2, 'max': 2},
            'body': step(),
          },
          'between': step(role: 'recovery', end: time(120)),
        },
        warmup: step(end: time(600)),
        cooldown: step(end: {'kind': 'manual'}),
      );
      expect(result.ready, true);
      final all = steps(result);
      expect(all.length, 10);
      expect(
        all
            .where((s) => (s['stepType'] as Map)['stepTypeKey'] == 'recovery')
            .length,
        2,
      );
      expect((all.first['stepType'] as Map)['stepTypeKey'], 'warmup');
      expect((all.last['stepType'] as Map)['stepTypeKey'], 'cooldown');
      expect(all.last.containsKey('endConditionValue'), false);
      expect(all.map((s) => s['stepOrder']), List.generate(10, (i) => i + 1));
      expect(result.warnings.single, contains('maximum repetitions'));
    },
  );
  test(
    'converts VMA range to speed, faster bound first; preserves scoped notes',
    () {
      final result = export({
        'kind': 'sequence',
        'notes': [
          {'text': 'Block note'},
        ],
        'children': [
          step(
            targets: [numeric('vma_percent', 80, 85)],
            notes: [
              {'text': 'Step note'},
            ],
          ),
        ],
      });
      final first = steps(result).single;
      expect(first['targetValueOne'], closeTo(16 * .85 / 3.6, .000001));
      expect(first['targetValueTwo'], closeTo(16 * .8 / 3.6, .000001));
      expect(first['description'], contains('Block note\nStep note'));
      expect(result.payload['description'], 'Session note\nGroup note');
    },
  );
  test('duration ranges default to the maximum and remain editable', () {
    final main = step(
      end: {
        'kind': 'time',
        'seconds': {'min': 60, 'max': 90},
      },
    );
    expect(export(main).ready, true);
    expect(steps(export(main)).single['endConditionValue'], 90);
    final selected = export(main, values: {'main/end': 75});
    expect(selected.ready, true);
    expect(selected.inputs.single.resolved, true);
    expect(steps(selected).single['endConditionValue'], 75);
    expect(export(main, values: {'main/end': 100}).ready, false);
    expect(export(main, values: {'main/end': double.nan}).ready, false);
  });
  test('lap range selection uses explicit length or default 400 m', () {
    final main = step(
      end: {
        'kind': 'laps',
        'count': {'min': 2, 'max': 3},
      },
    );
    expect(export(main).ready, true);
    expect(export(main, values: {'main/end': 2.5}).ready, false);
    final resolved = export(main, values: {'main/end': 3});
    expect(steps(resolved).single['endConditionValue'], 1200);
    expect(resolved.warnings, contains(contains('400 m')));
    final explicit = step(
      end: {
        'kind': 'laps',
        'count': {'min': 2, 'max': 2},
        'lapLengthMeters': 300,
      },
    );
    expect(steps(export(explicit)).single['endConditionValue'], 600);
  });
  test('alternatives need selection and optional blocks default included', () {
    final main = {
      'kind': 'choice',
      'reason': 'Choose terrain',
      'options': [
        {'label': 'Track', 'plan': step()},
        {'label': 'Road', 'plan': step(end: time(60))},
      ],
    };
    expect(export(main).ready, false);
    final prefilled = export(main, defaultChoices: true);
    expect(prefilled.ready, true);
    expect(prefilled.inputs.single.value, 0);
    expect(prefilled.payload, export(main, values: {'main': 0}).payload);
    final selected = export(main, values: {'main': 1});
    expect(selected.ready, true);
    expect(steps(selected).single['endConditionValue'], 60);
    expect(export({...step(), 'optional': true}).ready, true);
    expect(
      export({...step(), 'optional': true}, values: {'main/optional': 1}).ready,
      false,
    );
  });
  test('unsupported end conditions automatically become LAP steps', () {
    for (final end in [
      {'kind': 'event', 'description': 'Reach stadium'},
      {'kind': 'unknown', 'text': 'Missing'},
      {
        'kind': 'repetitions',
        'count': {'min': 10, 'max': 10},
      },
      {
        'kind': 'any_of',
        'conditions': [
          time(60),
          {'kind': 'manual'},
        ],
      },
    ]) {
      final result = export(step(end: end));
      expect(result.ready, true);
      expect(
        steps(result).single['endCondition']['conditionTypeKey'],
        'lap.button',
      );
    }
    final event = export(
      step(end: {'kind': 'event', 'description': 'Reach stadium'}),
    );
    expect(steps(event).single['description'], contains('Reach stadium'));
  });
  test(
    'unsupported targets retain instruction and explicitly warn about alerts',
    () {
      final result = export(
        step(
          targets: [
            numeric('heart_rate_bpm', 130, 150),
            {
              'kind': 'progression',
              'metric': 'vma_percent',
              'from': 80,
              'to': 100,
              'scope': 'within_step',
              'distribution': 'linear',
            },
          ],
        ),
      );
      expect(result.ready, true);
      expect(result.warnings.single, contains('without watch alerts'));
      expect(steps(result).single['description'], contains('130–150 bpm'));
      expect(
        (steps(result).single['targetType'] as Map)['workoutTargetTypeKey'],
        'no.target',
      );
    },
  );
  test('pace inversion, invalid VMA and conflicting pace alerts', () {
    final result = export(
      step(targets: [numeric('pace_seconds_per_km', 240, 300)]),
    );
    expect(steps(result).single['targetValueOne'], closeTo(1000 / 240, .00001));
    expect(steps(result).single['targetValueTwo'], closeTo(1000 / 300, .00001));
    expect(
      export(step(targets: [numeric('vma_percent', 100, 100)]), vma: 0).ready,
      false,
    );
    expect(
      export(
        step(
          targets: [
            numeric('speed_mps', 3, 4),
            numeric('vma_percent', 90, 100),
          ],
        ),
      ).ready,
      false,
    );
  });
  test('bounds expansion and warns when shortening descriptions', () {
    expect(
      export({
        'kind': 'repeat',
        'count': {'min': 1000000, 'max': 1000000},
        'body': step(),
      }).ready,
      false,
    );
    final result = export(
      step(
        notes: [
          {'text': List.filled(1200, 'é').join()},
        ],
      ),
    );
    expect((steps(result).single['description'] as String).runes.length, 1024);
    expect(result.warnings, contains(contains('shortened')));
  });
  test('export representative fixture for independent proxy validation', () {
    final result = export(
      step(targets: [numeric('vma_percent', 80, 85)]),
      warmup: step(end: time(60)),
      cooldown: step(end: {'kind': 'manual'}),
    );
    expect(result.ready, true);
    final output = Platform.environment['GARMIN_CONTRACT_OUTPUT'];
    if (output != null) {
      File(output).writeAsStringSync(jsonEncode(result.payload));
    }
  });
}
