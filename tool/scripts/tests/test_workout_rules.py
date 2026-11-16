"""Firestore rules integration test, run only through the local emulator."""
import base64
import json
import os
import re
import time
import unittest
import urllib.error
import urllib.request

PROJECT = 'demo-vma-workout'


def encode(value):
    return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip('=')


class WorkoutRulesTests(unittest.TestCase):
    def test_access_rules(self):
        host = os.environ.get('FIRESTORE_EMULATOR_HOST', '')
        if not re.fullmatch(r'(127\.0\.0\.1|localhost):[0-9]+', host):
            self.fail('Run only through the local Firestore emulator: npm run test:workout-rules')
        base = f'http://{host}/v1/projects/{PROJECT}/databases/(default)/documents'
        now = int(time.time())
        token = encode({'alg': 'none', 'typ': 'JWT'}) + '.' + encode({
            'iss': f'https://securetoken.google.com/{PROJECT}', 'aud': PROJECT,
            'auth_time': now, 'iat': now, 'exp': now + 3600,
            'sub': 'workout-reader', 'user_id': 'workout-reader',
            'firebase': {'sign_in_provider': 'anonymous', 'identities': {}},
        }) + '.'
        # Bypass local proxies and redirects; requests must stay on the emulator.
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, headers, newurl):
                return None
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())

        def request(route, *, auth=token, method='GET', body=None):
            headers = {'Content-Type': 'application/json'}
            if auth:
                headers['Authorization'] = 'Bearer ' + auth
            req = urllib.request.Request(base + route, headers=headers, method=method,
                                         data=None if body is None else json.dumps(body).encode())
            try:
                response = opener.open(req, timeout=30)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                return response.code, response.read().decode()

        for document_id in ['workout_plan', 'training_plan', 'other']:
            status, body = request('/app_documents/' + document_id, auth='owner', method='PATCH',
                                   body={'fields': {'content': {'stringValue': 'fixture'}}})
            self.assertEqual(status, 200, body)
        for document_id in ['workout_plan', 'training_plan']:
            with self.subTest(read=document_id):
                status, body = request('/app_documents/' + document_id)
                self.assertEqual(status, 200, body)
        for route, options in [
            ('/app_documents/workout_plan', {'auth': None}),
            ('/app_documents/other', {}),
            ('/app_documents', {}),
            ('/app_documents/workout_plan', {'method': 'PATCH', 'body': {'fields': {'content': {'stringValue': 'bad'}}}}),
            ('/app_documents/workout_plan', {'method': 'DELETE'}),
        ]:
            with self.subTest(route=route, options=options):
                status, body = request(route, **options)
                self.assertEqual(status, 403, body)


if __name__ == '__main__':
    unittest.main()
