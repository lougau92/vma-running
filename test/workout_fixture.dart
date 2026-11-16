import 'dart:convert';
import 'dart:io';

Map<String, dynamic> workoutFixture({
  String title = 'Test workout',
  String warmup = 'Easy warmup',
  int groups = 1,
}) => {
  'schemaVersion': '0.1',
  'status': 'workout',
  'sources': [
    {'type': 'email', 'reference': 'fixture.eml'},
  ],
  'workouts': [
    {
      'id': 'fixture',
      'title': title,
      'sport': 'running',
      'versions': List.generate(
        groups,
        (i) => {
          'label': 'Group ${i + 1}',
          'warmup': {
            'status': 'specified',
            'plan': {
              'kind': 'step',
              'role': 'effort',
              'end': {'kind': 'event', 'description': warmup},
            },
          },
          'main': {
            'status': 'specified',
            'plan': {
              'kind': 'repeat',
              'count': {'min': 4, 'max': 4},
              'body': {
                'kind': 'step',
                'role': 'effort',
                'end': {
                  'kind': 'distance',
                  'meters': {'min': 400, 'max': 400},
                },
                'targets': [
                  {
                    'kind': 'numeric',
                    'metric': 'vma_percent',
                    'value': {'min': 100, 'max': 100},
                  },
                ],
              },
              'between': {
                'kind': 'step',
                'role': 'recovery',
                'end': {
                  'kind': 'time',
                  'seconds': {'min': 60, 'max': 60},
                },
              },
            },
          },
          'cooldown': {'status': 'not_specified'},
        },
      ),
    },
  ],
  'issues': [],
};

Map<String, dynamic> workoutCase(Map<String, dynamic> scenario) {
  final d =
      jsonDecode(File('test/fixtures/workouts/valid.json').readAsStringSync())
          as Map<String, dynamic>;
  for (final change in scenario['changes'] as List) {
    final path = List<Object>.from(change['path'] as List);
    final last = path.removeLast();
    dynamic parent = d;
    for (final key in path) {
      parent = parent[key];
    }
    if (change['remove'] == true) {
      (parent as Map).remove(last);
    } else {
      parent[last] = change['value'];
    }
  }
  return d;
}
