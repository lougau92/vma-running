import 'workout_schema.g.dart';

void validateWorkoutSchema(Object? value) => _check(value, workoutSchema, '');
Never _fail(String path, String message) =>
    throw FormatException('$path: $message');
void _check(Object? value, Map<String, dynamic> schema, String path) {
  if (schema.containsKey(r'$ref')) {
    final name = (schema[r'$ref'] as String).split('/').last;
    _check(
      value,
      (workoutSchema[r'$defs'] as Map<String, dynamic>)[name]
          as Map<String, dynamic>,
      path,
    );
    return;
  }
  bool matches(Map<String, dynamic> candidate) {
    try {
      _check(value, candidate, path);
      return true;
    } on FormatException {
      return false;
    }
  }

  if (schema.containsKey('const') && value != schema['const']) {
    _fail(path, 'Unexpected constant');
  }
  if (schema['enum'] case final List values) {
    if (!values.contains(value)) _fail(path, 'Unexpected value');
  }
  if (schema['oneOf'] case final List options) {
    if (options.where((s) => matches(s as Map<String, dynamic>)).length != 1) {
      _fail(path, 'Unsupported or invalid structure');
    }
  }
  if (schema['allOf'] case final List options) {
    for (final option in options) {
      _check(value, option as Map<String, dynamic>, path);
    }
  }
  if (schema['not'] case final Map<String, dynamic> excluded) {
    if (matches(excluded)) _fail(path, 'Disallowed structure');
  }
  if (schema['if'] case final Map<String, dynamic> condition) {
    final branch = schema[matches(condition) ? 'then' : 'else'];
    if (branch != null) _check(value, branch as Map<String, dynamic>, path);
  }
  final valid = switch (schema['type']) {
    'object' => value is Map<String, dynamic>,
    'array' => value is List,
    'string' => value is String,
    'boolean' => value is bool,
    'number' => value is num && value.isFinite,
    'integer' => value is int,
    null => true,
    _ => false,
  };
  if (!valid) _fail(path, 'Invalid type');
  if (value is Map<String, dynamic>) {
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    for (final key in schema['required'] as List? ?? []) {
      if (!value.containsKey(key)) _fail(path, 'Missing $key');
    }
    for (final entry in value.entries) {
      final child = properties[entry.key];
      if (child != null) {
        _check(
          entry.value,
          child as Map<String, dynamic>,
          '$path/${entry.key}',
        );
      } else if (schema['additionalProperties'] == false) {
        _fail(path, 'Unknown property ${entry.key}');
      }
    }
  }
  if (value is List) {
    if (value.length < (schema['minItems'] as num? ?? 0) ||
        value.length > (schema['maxItems'] as num? ?? double.infinity)) {
      _fail(path, 'Invalid array length');
    }
    if (schema['items'] case final Map<String, dynamic> item) {
      for (var i = 0; i < value.length; i++) {
        _check(value[i], item, '$path/$i');
      }
    }
  }
  if (value is num) {
    if (value < (schema['minimum'] as num? ?? double.negativeInfinity) ||
        value > (schema['maximum'] as num? ?? double.infinity) ||
        (schema.containsKey('exclusiveMinimum') &&
            value <= (schema['exclusiveMinimum'] as num))) {
      _fail(path, 'Quantity out of bounds');
    }
  }
  if (value is String) {
    if (value.length < (schema['minLength'] as num? ?? 0)) {
      _fail(path, 'Empty text');
    }
    if (schema['format'] == 'date' && !_date(value)) {
      _fail(path, 'Invalid date');
    }
    if (schema['format'] == 'date-time' && !_timestamp(value)) {
      _fail(path, 'Invalid timestamp');
    }
  }
}

bool _date(String value) {
  final date = DateTime.tryParse(value);
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
      date != null &&
      date.year >= 1 &&
      date.year <= 9999 &&
      date.toIso8601String().startsWith(value);
}

bool _timestamp(String value) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null || !_date(match[1]!) || DateTime.tryParse(value) == null) {
    return false;
  }
  if (int.parse(match[2]!) > 23 ||
      int.parse(match[3]!) > 59 ||
      int.parse(match[4]!) > 59) {
    return false;
  }
  final zone = match[5]!;
  return zone.length == 1 ||
      (int.parse(zone.substring(1, 3)) <= 23 &&
          int.parse(zone.substring(4, 6)) <= 59);
}
