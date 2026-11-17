import 'dart:convert';

import '../workouts/workout.dart';

/// Fully synthetic workout data shared by visual previews and render checks.
final Map<String, dynamic> workoutPreviewDocument = {
  'schemaVersion': '0.1',
  'status': 'workout',
  'sources': [
    {'type': 'email', 'reference': 'synthetic-preview'},
  ],
  'notes': [
    {
      'text': 'Adapter l’allure aux consignes du coach.',
      'category': 'instruction',
    },
  ],
  'workouts': [
    {
      'id': 'preview-intervals',
      'title': 'Séance de fractionné',
      'sport': 'running',
      'scheduledDate': '2030-04-04',
      'location': 'Piste d’exemple',
      'notes': [
        {
          'text': 'Rester relâché pendant les accélérations.',
          'category': 'technique',
        },
      ],
      'versions': [
        for (final count in [6, 5])
          {
            'label': 'Groupe $count',
            'audience': count == 6 ? 'Groupe confirmé' : 'Groupe progression',
            'warmup': {
              'status': 'specified',
              'plan': _step('effort', _time(1200), label: 'Footing facile'),
            },
            'main': {
              'status': 'specified',
              'plan': {
                'kind': 'sequence',
                'label': 'Bloc principal',
                'declaredDurationSeconds': {'min': 2400, 'max': 2400},
                'children': [
                  {
                    'kind': 'repeat',
                    'count': {'min': 2, 'max': 2},
                    'body': {
                      'kind': 'sequence',
                      'children': [
                        {
                          'kind': 'repeat',
                          'count': {'min': count, 'max': count},
                          'body': _step(
                            'effort',
                            _distance(200),
                            targets: [_vma(count == 6 ? 110 : 105)],
                          ),
                          'between': _step(
                            'recovery',
                            _time(45, 60),
                            movement: {'mode': 'unspecified'},
                          ),
                        },
                        {
                          'kind': 'repeat',
                          'count': {'min': 4, 'max': 4},
                          'body': _step(
                            'effort',
                            _distance(400),
                            targets: [_vma(100)],
                          ),
                          'between': _step(
                            'recovery',
                            _time(90),
                            movement: {'mode': 'passive'},
                          ),
                        },
                      ],
                    },
                    'between': _step(
                      'recovery',
                      _time(180),
                      movement: {'mode': 'passive'},
                    ),
                  },
                  {
                    'kind': 'choice',
                    'label': 'Variante selon le terrain',
                    'reason': 'Choisir une seule option selon les conditions.',
                    'options': [
                      {
                        'label': 'Piste',
                        'audience': 'Sur piste',
                        'plan': _step(
                          'effort',
                          _distance(1000),
                          targets: [_vma(95)],
                        ),
                      },
                      {
                        'label': 'Côtes',
                        'plan': _step('effort', {
                          'kind': 'event',
                          'description': 'Retour en footing dans la descente',
                        }),
                      },
                    ],
                  },
                  {
                    'kind': 'step',
                    'role': 'effort',
                    'optional': true,
                    'label': 'Lignes droites souples',
                    'end': {
                      'kind': 'repetitions',
                      'count': {'min': 6, 'max': 6},
                    },
                    'notes': [
                      {
                        'text': 'Récupération complète entre les lignes.',
                        'category': 'instruction',
                      },
                    ],
                  },
                ],
              },
            },
            'cooldown': count == 6
                ? {
                    'status': 'specified',
                    'plan': _step(
                      'effort',
                      _time(600),
                      label: 'Retour au calme',
                    ),
                  }
                : {'status': 'not_specified'},
          },
      ],
    },
    {
      'id': 'preview-easy-run',
      'title': 'Footing de récupération',
      'sport': 'running',
      'scheduledDate': '2030-04-06',
      'location': 'Parc exemple',
      'versions': [
        {
          'label': 'Tous les groupes',
          'warmup': {'status': 'not_specified'},
          'main': {
            'status': 'specified',
            'plan': _step('effort', _time(2700), targets: [_vma(70)]),
          },
          'cooldown': {'status': 'explicitly_none'},
        },
      ],
    },
  ],
  'issues': [
    {
      'severity': 'warning',
      'code': 'inferred',
      'message': 'La variante dépend du terrain disponible.',
      'paths': ['/workouts/0/versions/0/main/plan/children/1'],
    },
  ],
};

final String workoutPreviewJson = jsonEncode(workoutPreviewDocument);
final WorkoutConversion workoutPreviewConversion = WorkoutConversion.parse(
  workoutPreviewJson,
);

Map<String, dynamic> _step(
  String role,
  Map<String, dynamic> end, {
  String? label,
  List<Map<String, dynamic>> targets = const [],
  Map<String, dynamic>? movement,
}) => {
  'kind': 'step',
  'role': role,
  'end': end,
  if (label != null) 'label': label,
  if (targets.isNotEmpty) 'targets': targets,
  if (movement != null) 'movement': movement,
};

Map<String, dynamic> _time(int seconds, [int? max]) => {
  'kind': 'time',
  'seconds': {'min': seconds, 'max': max ?? seconds},
};

Map<String, dynamic> _distance(int meters, [int? max]) => {
  'kind': 'distance',
  'meters': {'min': meters, 'max': max ?? meters},
};

Map<String, dynamic> _vma(int value) => {
  'kind': 'numeric',
  'metric': 'vma_percent',
  'value': {'min': value, 'max': value},
};
