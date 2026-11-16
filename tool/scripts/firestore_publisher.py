"""Google authentication and a single, non-retried Firestore commit."""
import re


def validate_project(project):
    if not isinstance(project, str) or not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', project):
        raise ValueError('Invalid Firebase project ID.')


def authenticated_client(project):
    """Use ADC (locally: gcloud auth application-default login)."""
    validate_project(project)
    # Keep authentication dependencies and credential discovery out of dry runs.
    import google.auth
    from google.auth.transport.requests import Request
    import requests

    credentials, _ = google.auth.default(scopes=['https://www.googleapis.com/auth/datastore'])
    session = requests.Session()
    try:
        credentials.refresh(Request(session=session))
        headers = {}
        credentials.apply(headers)
        session.headers.update(headers)
        return session
    except Exception:
        session.close()
        raise


def commit_writes(client, project, writes):
    validate_project(project)
    url = f'https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents:commit'
    # requests defaults to zero retries. Do not follow redirects or replay a
    # publication on auth failures: a missing acknowledgement is inconclusive.
    response = client.post(url, json={'writes': writes}, timeout=30, allow_redirects=False)
    try:
        if response.status_code != 200:
            raise RuntimeError('Firestore commit failed.')
        results = response.json().get('writeResults')
        if not isinstance(results, list) or len(results) != len(writes):
            raise RuntimeError('Server did not confirm every write; check the database before retrying.')
    finally:
        response.close()
