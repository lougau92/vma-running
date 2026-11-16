"""Validate, preview and explicitly publish the current workout conversion."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

# Also support an absolute script path from outside the repository.
if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tool.scripts.firestore_publisher import authenticated_client, commit_writes, validate_project
from tool.scripts.workout_validation import validate_document

DOCUMENT_PATH = 'app_documents/workout_plan'


def validate_workout(content):
    if not content.strip() or len(content.encode('utf-8')) > 900_000:
        raise ValueError('Workout must be nonempty and at most 900,000 UTF-8 bytes.')
    conversion = json.loads(content)
    validate_document(conversion, publication=True, require_schema=True)
    return conversion


def workout_write(project, content):
    validate_project(project)
    return {
        'update': {
            'name': f'projects/{project}/databases/(default)/documents/{DOCUMENT_PATH}',
            'fields': {
                'content': {'stringValue': content},
                'contentHash': {'stringValue': hashlib.sha256(content.encode('utf-8')).hexdigest()},
            },
        },
        'updateMask': {'fieldPaths': ['content', 'contentHash']},
        'updateTransforms': [{'fieldPath': 'publishedAt', 'setToServerValue': 'REQUEST_TIME'}],
    }


def publish_workout(client, project, content):
    validate_workout(content)
    commit_writes(client, project, [workout_write(project, content)])


def main(args=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--file', type=Path)
    parser.add_argument('--project', default='vma-training')
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--approve', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    options = parser.parse_args(args)
    if options.write and options.dry_run:
        raise ValueError('Choose --write or --dry-run.')
    if options.write and not options.approve:
        raise ValueError('--write requires --approve: confirm you reviewed the source and conversion.')
    if options.file is None:
        raise ValueError('--file PATH is required.')
    validate_project(options.project)
    # Preserve exact UTF-8 bytes, including CRLF, in the hash and remote content.
    content = options.file.read_bytes().decode('utf-8')
    conversion = validate_workout(content)
    write = workout_write(options.project, content)
    print(f'Project: {options.project}; document: {DOCUMENT_PATH}')
    print(f"{len(content.encode('utf-8'))} bytes; SHA-256: {write['update']['fields']['contentHash']['stringValue']}")
    for workout in conversion['workouts']:
        labels = ', '.join(version['label'] for version in workout['versions'])
        print(f"  {workout['id']}: {workout['title']} — {labels}")
    for issue in conversion['issues']:
        resolved = ' — Resolved: ' + issue['resolution']['text'] if 'resolution' in issue else ''
        print(f"  {issue['severity']}: {issue['message']}{resolved}")
    if not options.write:
        print('Dry run: validated locally; no authentication or network calls.')
        return
    try:
        client = authenticated_client(options.project)
    except Exception:
        raise RuntimeError('Google authentication failed. Run gcloud auth application-default login and verify project access.') from None
    try:
        commit_writes(client, options.project, [write])
    except Exception:
        raise RuntimeError('Publication not confirmed. Check the remote document before retrying; no automatic retry was made.') from None
    finally:
        client.close()
    print('Published current workout.')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
