"""Validate and publish encrypted club communications and challenge rankings."""
import argparse
import json
from pathlib import Path
import sys

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tool.scripts.firestore_publisher import authenticated_client, commit_writes, validate_project

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    'club_communications': 'assets/communications/messages.json',
    'challenge_classement': 'assets/enjambee_challenge/classement_challenge_enjambee_2025_12_10_2025.csv',
}


def validate_content(document_id, content):
    if document_id not in SOURCES:
        raise ValueError('Unknown content document.')
    if not content.strip() or len(content.encode('utf-8')) > 1_000_000:
        raise ValueError(f'{document_id}: file must be nonempty and at most 1,000,000 UTF-8 bytes.')
    if document_id == 'challenge_classement':
        if content.split('\n', 1)[0].removesuffix('\r') != 'Nom,Prenom,Dernière course,Total,Participations':
            raise ValueError(f'{document_id}: unexpected CSV header.')
        return
    try:
        data = json.loads(content)
    except ValueError:
        raise ValueError(f'{document_id}: invalid JSON.') from None
    if not isinstance(data, dict):
        raise ValueError(f'{document_id}: expected encrypted version-2 messages, not raw messages.')
    kdf = data.get('kdf')
    messages = data.get('messages')
    if (data.get('version') != 2 or not isinstance(messages, list)
            or not isinstance(kdf, dict) or not isinstance(kdf.get('salt'), str)
            or type(kdf.get('iterations')) is not int or kdf['iterations'] < 1
            or not all(isinstance(m, dict)
                       and all(isinstance(m.get(k), str) and m[k] for k in ('nonce', 'cipher', 'tag'))
                       and not any(k in m for k in ('title', 'summary', 'body')) for m in messages)):
        raise ValueError(f'{document_id}: expected encrypted version-2 messages, not raw messages.')


def load_content(ids=None, directory=ROOT):
    ids = list(SOURCES) if ids is None else list(ids)
    if not ids or any(document_id not in SOURCES for document_id in ids):
        raise ValueError('Choose documents from: ' + ', '.join(SOURCES) + '.')
    documents = []
    for document_id in ids:
        file = SOURCES[document_id]
        content = (Path(directory) / file).read_bytes().decode('utf-8')
        validate_content(document_id, content)
        documents.append({'id': document_id, 'file': file, 'content': content})
    return documents


def commit_body(project, documents):
    validate_project(project)
    writes = []
    for document in documents:
        document_id, content = document['id'], document['content']
        validate_content(document_id, content)
        writes.append({
            'update': {
                'name': f'projects/{project}/databases/(default)/documents/app_documents/{document_id}',
                'fields': {'content': {'stringValue': content}},
            },
            'updateMask': {'fieldPaths': ['content']},
        })
    return {'writes': writes}


def publish(client, project, documents):
    commit_writes(client, project, commit_body(project, documents)['writes'])


def main(args=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', default='vma-training')
    parser.add_argument('--only', help='Comma-separated document IDs')
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    options = parser.parse_args(args)
    if options.write and options.dry_run:
        raise ValueError('Choose --write or --dry-run.')
    validate_project(options.project)
    documents = load_content(None if options.only is None else options.only.split(','))
    commit_body(options.project, documents)
    print(f'Project: {options.project}; database: (default); collection: app_documents')
    for document in documents:
        size = len(document['content'].encode('utf-8'))
        print(f"  {document['id']} <- {document['file']} ({size} bytes)")
    if not options.write:
        print('Dry run: validated locally; no authentication or network calls. Add --write to publish.')
        return
    try:
        client = authenticated_client(options.project)
    except Exception:
        raise RuntimeError('Google authentication failed. Run gcloud auth application-default login and verify project access.') from None
    try:
        publish(client, options.project, documents)
    except Exception:
        raise RuntimeError('Publication not confirmed. Check the remote documents before retrying; no automatic retry was made.') from None
    finally:
        client.close()
    print(f'Published {len(documents)} document(s) atomically. Other fields were preserved.')


if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
