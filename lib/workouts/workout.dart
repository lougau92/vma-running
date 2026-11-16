import 'dart:convert';
import 'schema_validation.dart';

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    List<T>.unmodifiable(
      (value as List? ?? []).map((v) => parse(v as Map<String, dynamic>)),
    );
List<WorkoutNote> _notes(Map<String, dynamic> j) =>
    _list(j['notes'], WorkoutNote.new);

class WorkoutNote {
  WorkoutNote(Map<String, dynamic> j)
    : text = j['text'] as String,
      category = j['category'] as String?;
  final String text;
  final String? category;
}

class WorkoutSource {
  WorkoutSource(Map<String, dynamic> j)
    : type = j['type'] as String,
      reference = j['reference'] as String,
      subject = j['subject'] as String?,
      sentAt = j['sentAt'] as String?;
  final String type, reference;
  final String? subject, sentAt;
}

class WorkoutIssue {
  WorkoutIssue(Map<String, dynamic> j)
    : severity = j['severity'] as String,
      code = j['code'] as String,
      message = j['message'] as String,
      paths = List<String>.unmodifiable(j['paths'] as List),
      resolution =
          (j['resolution'] as Map<String, dynamic>?)?['text'] as String?,
      resolvedBy = (j['resolution'] as Map<String, dynamic>?)?['by'] as String?;
  final String severity, code, message;
  final List<String> paths;
  final String? resolution, resolvedBy;
}

class Bounds {
  Bounds(Map<String, dynamic> j)
    : min = (j['min'] as num).toDouble(),
      max = (j['max'] as num).toDouble();
  final double min, max;
}

class WorkoutConversion {
  WorkoutConversion._(Map<String, dynamic> j)
    : sources = _list(j['sources'], WorkoutSource.new),
      workouts = _list(j['workouts'], WorkoutSession.new),
      notes = _notes(j),
      issues = _list(j['issues'], WorkoutIssue.new);
  factory WorkoutConversion.parse(String text) {
    final value = jsonDecode(text);
    validateWorkoutSchema(value);
    final j = value as Map<String, dynamic>;
    _semantic(j);
    if (j['status'] != 'workout') {
      throw const FormatException('Not a workout publication');
    }
    if ((j['issues'] as List).any(
      (i) => i['severity'] == 'blocking' && !i.containsKey('resolution'),
    )) {
      throw const FormatException('Unresolved blocking issue');
    }
    return WorkoutConversion._(j);
  }
  final List<WorkoutSource> sources;
  final List<WorkoutSession> workouts;
  final List<WorkoutNote> notes;
  final List<WorkoutIssue> issues;
}

class WorkoutSession {
  WorkoutSession(Map<String, dynamic> j)
    : id = j['id'] as String,
      title = j['title'] as String,
      scheduledDate = j['scheduledDate'] as String?,
      location = j['location'] as String?,
      notes = _notes(j),
      versions = _list(j['versions'], WorkoutVersion.new);
  final String id, title;
  final String? scheduledDate, location;
  final List<WorkoutNote> notes;
  final List<WorkoutVersion> versions;
}

class WorkoutVersion {
  WorkoutVersion(Map<String, dynamic> j)
    : label = j['label'] as String,
      audience = j['audience'] as String?,
      notes = _notes(j),
      warmup = WorkoutPhase(j['warmup'] as Map<String, dynamic>),
      main = WorkoutPhase(j['main'] as Map<String, dynamic>),
      cooldown = WorkoutPhase(j['cooldown'] as Map<String, dynamic>);
  final String label;
  final String? audience;
  final List<WorkoutNote> notes;
  final WorkoutPhase warmup, main, cooldown;
}

class WorkoutPhase {
  WorkoutPhase(Map<String, dynamic> j)
    : status = j['status'] as String,
      plan = j['plan'] == null
          ? null
          : WorkoutNode.parse(j['plan'] as Map<String, dynamic>);
  final String status;
  final WorkoutNode? plan;
}

sealed class WorkoutNode {
  WorkoutNode(Map<String, dynamic> j)
    : label = j['label'] as String?,
      optional = j['optional'] == true,
      notes = _notes(j);
  final String? label;
  final bool optional;
  final List<WorkoutNote> notes;
  static WorkoutNode parse(Map<String, dynamic> j) => switch (j['kind']) {
    'step' => WorkoutStep(j),
    'sequence' => WorkoutSequence(j),
    'repeat' => WorkoutRepeat(j),
    'choice' => WorkoutChoice(j),
    _ => throw const FormatException('Unknown node'),
  };
}

class WorkoutStep extends WorkoutNode {
  WorkoutStep(super.j)
    : role = j['role'] as String,
      end = WorkoutEnd(j['end'] as Map<String, dynamic>),
      targets = _list(j['targets'], WorkoutTarget.new),
      movement = j['movement'] == null
          ? null
          : WorkoutMovement(j['movement'] as Map<String, dynamic>);
  final String role;
  final WorkoutEnd end;
  final List<WorkoutTarget> targets;
  final WorkoutMovement? movement;
}

class WorkoutSequence extends WorkoutNode {
  WorkoutSequence(super.j)
    : children = _list(j['children'], WorkoutNode.parse),
      declaredDuration = j['declaredDurationSeconds'] == null
          ? null
          : Bounds(j['declaredDurationSeconds'] as Map<String, dynamic>);
  final List<WorkoutNode> children;
  final Bounds? declaredDuration;
}

class WorkoutRepeat extends WorkoutNode {
  WorkoutRepeat(super.j)
    : count = Bounds(j['count'] as Map<String, dynamic>),
      body = WorkoutNode.parse(j['body'] as Map<String, dynamic>),
      between = j['between'] == null
          ? null
          : WorkoutNode.parse(j['between'] as Map<String, dynamic>);
  final Bounds count;
  final WorkoutNode body;
  final WorkoutNode? between;
}

class WorkoutChoice extends WorkoutNode {
  WorkoutChoice(super.j)
    : reason = j['reason'] as String,
      options = _list(j['options'], WorkoutOption.new);
  final String reason;
  final List<WorkoutOption> options;
}

class WorkoutOption {
  WorkoutOption(Map<String, dynamic> j)
    : label = j['label'] as String,
      audience = j['audience'] as String?,
      plan = WorkoutNode.parse(j['plan'] as Map<String, dynamic>);
  final String label;
  final String? audience;
  final WorkoutNode plan;
}

class WorkoutEnd {
  WorkoutEnd(Map<String, dynamic> j)
    : kind = j['kind'] as String,
      quantity = j['seconds'] != null
          ? Bounds(j['seconds'] as Map<String, dynamic>)
          : j['meters'] != null
          ? Bounds(j['meters'] as Map<String, dynamic>)
          : j['count'] != null
          ? Bounds(j['count'] as Map<String, dynamic>)
          : null,
      lapLength = (j['lapLengthMeters'] as num?)?.toDouble(),
      description = (j['description'] ?? j['text']) as String?,
      conditions = _list(j['conditions'], WorkoutEnd.new);
  final String kind;
  final Bounds? quantity;
  final double? lapLength;
  final String? description;
  final List<WorkoutEnd> conditions;
}

class WorkoutTarget {
  WorkoutTarget(Map<String, dynamic> j)
    : kind = j['kind'] as String,
      metric = j['metric'] as String?,
      value = j['kind'] == 'numeric'
          ? Bounds(j['value'] as Map<String, dynamic>)
          : null,
      effort = j['kind'] == 'effort' ? j['value'] as String : null,
      text = j['text'] as String?,
      from = (j['from'] as num?)?.toDouble(),
      to = (j['to'] as num?)?.toDouble(),
      scope = j['scope'] as String?,
      distribution = j['distribution'] as String?,
      approximate = j['approximate'] == true;
  final String kind;
  final String? metric, effort, text, scope, distribution;
  final Bounds? value;
  final double? from, to;
  final bool approximate;
}

class WorkoutMovement {
  WorkoutMovement(Map<String, dynamic> j)
    : mode = j['mode'] as String,
      allowed = List<String>.unmodifiable(j['allowed'] as List? ?? []);
  final String mode;
  final List<String> allowed;
}

void _semantic(Map<String, dynamic> document) {
  final issues = (document['issues'] as List).cast<Map<String, dynamic>>();
  bool covered(String path) => issues.any(
    (i) =>
        i['severity'] == 'blocking' &&
        (i['paths'] as List).any((p) => path == p || path.startsWith('$p/')),
  );
  for (final issue in issues) {
    for (final pointer in issue['paths'] as List) {
      _resolve(document, pointer as String);
    }
  }
  final ids = (document['workouts'] as List).map((w) => w['id']).toList();
  if (ids.toSet().length != ids.length) {
    throw const FormatException('Duplicate workout IDs');
  }
  bool recovery(Object? value) {
    final n = value as Map<String, dynamic>;
    return switch (n['kind']) {
      'step' => n['role'] == 'recovery',
      'sequence' => (n['children'] as List).every(recovery),
      'repeat' =>
        recovery(n['body']) && (n['between'] == null || recovery(n['between'])),
      'choice' => (n['options'] as List).every((o) => recovery(o['plan'])),
      _ => false,
    };
  }

  void visit(Object? value, String path, bool repeated) {
    if (value is Map<String, dynamic>) {
      if (value.containsKey('min') &&
          value.containsKey('max') &&
          (value['min'] as num) > (value['max'] as num)) {
        throw FormatException('$path: Reversed bounds');
      }
      if (value['kind'] == 'repeat' &&
          value.containsKey('between') &&
          ((value['count']['max'] as num) == 1 ||
              !recovery(value['between']))) {
        throw FormatException('$path: Invalid between recovery');
      }
      final movement = value['movement'] as Map<String, dynamic>?;
      final allowed = movement?['allowed'] as List? ?? [];
      final problem =
          value['kind'] == 'unknown' ||
          (path.contains('/versions/') &&
              path.endsWith('/main') &&
              value['status'] != 'specified') ||
          (movement?['mode'] == 'passive' &&
              allowed.isNotEmpty &&
              allowed.every((m) => ['run', 'jog', 'walk'].contains(m)));
      if (problem && !covered(path)) {
        throw FormatException('$path: Missing blocking issue');
      }
      final targets = value['targets'] as List? ?? [];
      final metrics = targets
          .where((t) => t.containsKey('metric'))
          .map((t) => t['metric'])
          .toList();
      if (metrics.toSet().length != metrics.length && !covered(path)) {
        throw FormatException('$path: Duplicate target metrics');
      }
      if (value['kind'] == 'progression' &&
          value['scope'] == 'across_iterations' &&
          !repeated) {
        throw FormatException('$path: Progression outside repeat');
      }
      if (value['kind'] == 'numeric' || value['kind'] == 'progression') {
        final vals = value['kind'] == 'numeric'
            ? [value['value']['min'], value['value']['max']]
            : [value['from'], value['to']];
        final limit = switch (value['metric']) {
          'rpe_0_10' => 10,
          'heart_rate_max_percent' => 100,
          _ => double.infinity,
        };
        if (vals.any((v) => (v as num) > limit)) {
          throw FormatException('$path: Target outside metric bounds');
        }
      }
      for (final e in value.entries) {
        visit(
          e.value,
          '$path/${e.key}',
          repeated ||
              (value['kind'] == 'repeat' &&
                  ['body', 'between'].contains(e.key)),
        );
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        visit(value[i], '$path/$i', repeated);
      }
    }
  }

  visit(document, '', false);
}

void _resolve(Object? value, String pointer) {
  if (pointer.isEmpty) return;
  if (!pointer.startsWith('/')) {
    throw const FormatException('Invalid issue path');
  }
  for (final part in pointer.substring(1).split('/')) {
    if (part.replaceAll('~0', '').replaceAll('~1', '').contains('~')) {
      throw const FormatException('Invalid issue path escape');
    }
    final key = part.replaceAll('~1', '/').replaceAll('~0', '~');
    if (value is List) {
      final i = int.tryParse(key);
      if (i == null || i < 0 || i >= value.length || i.toString() != key) {
        throw const FormatException('Invalid issue index');
      }
      value = value[i];
    } else if (value is Map<String, dynamic> && value.containsKey(key)) {
      value = value[key];
    } else {
      throw const FormatException('Unresolved issue path');
    }
  }
}
