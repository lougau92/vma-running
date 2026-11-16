"""Shared structural and semantic validation for conversion and publication."""
import json
from pathlib import Path
from tool.scripts.workout_model import WorkoutConversion

ROOT = Path(__file__).resolve().parents[2]


def resolve(document, pointer):
    if pointer == '':
        return document
    if not pointer.startswith('/'):
        raise ValueError(f'Invalid JSON Pointer: {pointer}')
    value = document
    for part in pointer[1:].split('/'):
        if '~' in part.replace('~0', '').replace('~1', ''):
            raise ValueError(f'Invalid JSON Pointer escape: {pointer}')
        key = part.replace('~1', '/').replace('~0', '~')
        if isinstance(value, list):
            if not key.isdecimal() or (len(key) > 1 and key.startswith('0')):
                raise ValueError(f'Invalid array index: {pointer}')
            value = value[int(key)]
        else:
            value = value[key]
    return value


def validate_document(document, *, publication=False, require_schema=False):
    WorkoutConversion.from_dict(document)
    checks = ['typed model', 'semantic checks', 'issue pointers']
    try:
        import jsonschema
    except ImportError:
        if require_schema:
            raise ValueError('Publication requires jsonschema; install tool/scripts/requirements.txt')
        checks.append('JSON Schema skipped (jsonschema unavailable)')
    else:
        schema = json.loads((ROOT / 'docs/workouts/workout.schema.json').read_text())
        try:
            jsonschema.Draft202012Validator(schema, format_checker=jsonschema.FormatChecker()).validate(document)
        except jsonschema.ValidationError as exc:
            raise ValueError(f'/{"/".join(map(str, exc.absolute_path))}: {exc.message}') from exc
        checks.append('JSON Schema')
    ids = [w['id'] for w in document['workouts']]
    if len(ids) != len(set(ids)):
        raise ValueError('Workout IDs must be unique within the envelope')
    issues = document['issues']
    for issue in issues:
        for pointer in issue['paths']:
            resolve(document, pointer)
    def covered(path):
        return any(i['severity'] == 'blocking' and any(
            path == p or path.startswith(p + '/') for p in i['paths']) for i in issues)
    def visit(value, path='', repeated=False):
        if isinstance(value, dict):
            problem = value.get('kind') == 'unknown'
            if '/versions/' in path and path.endswith('/main'):
                problem |= value.get('status') != 'specified'
            movement = value.get('movement', {})
            problem |= (movement.get('mode') == 'passive' and bool(movement.get('allowed'))
                        and set(movement['allowed']) <= {'run', 'jog', 'walk'})
            if problem and not covered(path):
                raise ValueError(f'{path}: missing blocking issue for unknown endpoint, missing main, or movement conflict')
            targets = value.get('targets', [])
            metrics = [t['metric'] for t in targets if 'metric' in t]
            if len(metrics) != len(set(metrics)) and not covered(path):
                raise ValueError(f'{path}: duplicate target metrics require a blocking issue')
            if value.get('kind') == 'progression' and value.get('scope') == 'across_iterations' and not repeated:
                raise ValueError(f'{path}: across-iteration progression must be inside a repeat')
            for key, item in value.items():
                visit(item, path + '/' + key, repeated or (value.get('kind') == 'repeat' and key in ('body', 'between')))
        elif isinstance(value, list):
            for index, item in enumerate(value):
                visit(item, path + '/' + str(index), repeated)
    visit(document)
    if document['status'] == 'unreadable' and not any(
            i['severity'] == 'blocking' and 'resolution' not in i for i in issues):
        raise ValueError('Unreadable extraction requires an unresolved blocking issue')
    if publication:
        if document['status'] != 'workout':
            raise ValueError('Only workout conversions can be published')
        if any(i['severity'] == 'blocking' and 'resolution' not in i for i in issues):
            raise ValueError('Resolve all blocking issues before publication')
    return checks


if __name__ == '__main__':
    import sys
    try:
        # Read the exact bytes selected by the publisher, avoiding file-change races.
        document = json.loads(sys.stdin.read())
        validate_document(document, publication=True, require_schema=True)
        print('PASS: schema, typed model, semantic checks, publication gate')
    except Exception as exc:
        print(f'Validation failed: {exc}', file=sys.stderr)
        sys.exit(1)
