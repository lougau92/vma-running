"""Publisher contract tests; no credentials or remote services required."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

from tool.scripts import publish_workout as publisher
from tool.scripts.firestore_publisher import authenticated_client, commit_writes

ROOT = Path(__file__).resolve().parents[3]
CONTENT = (ROOT / 'test/fixtures/workouts/valid.json').read_text()


class PublisherTests(unittest.TestCase):
    def test_contract_cases(self):
        cases = json.loads((ROOT / 'test/fixtures/workouts/contract_cases.json').read_text())
        for case in cases:
            with self.subTest(case=case['name']):
                document = json.loads(CONTENT)
                for change in case['changes']:
                    parent = document
                    for key in change['path'][:-1]:
                        parent = parent[key]
                    key = change['path'][-1]
                    if change.get('remove'):
                        del parent[key]
                    else:
                        parent[key] = copy.deepcopy(change['value'])
                if case['valid']:
                    publisher.validate_workout(json.dumps(document))
                else:
                    with self.assertRaises(Exception):
                        publisher.validate_workout(json.dumps(document))

    def test_all_features_and_input_bounds(self):
        publisher.validate_workout((ROOT / 'test/fixtures/workouts/all_features.json').read_text())
        for content in ['', '{', 'é' * 450001]:
            with self.subTest(content=content[:10]), self.assertRaises(Exception):
                publisher.validate_workout(content)

    def test_exact_content_hash_and_single_commit(self):
        client = Mock()
        client.post.return_value.status_code = 200
        client.post.return_value.json.return_value = {'writeResults': [{}]}
        content = CONTENT.replace('\n', '\r\n')
        publisher.publish_workout(client, 'vma-training', content)
        client.post.assert_called_once()
        args, kwargs = client.post.call_args
        self.assertEqual(args[0], 'https://firestore.googleapis.com/v1/projects/vma-training/databases/(default)/documents:commit')
        self.assertEqual(kwargs['timeout'], 30)
        self.assertFalse(kwargs['allow_redirects'])
        self.assertEqual(len(kwargs['json']['writes']), 1)
        write = kwargs['json']['writes'][0]
        self.assertEqual(write, publisher.workout_write('vma-training', content))
        self.assertEqual(write['update']['name'], 'projects/vma-training/databases/(default)/documents/app_documents/workout_plan')
        self.assertEqual(write['update']['fields']['content']['stringValue'], content)
        self.assertEqual(write['update']['fields']['contentHash']['stringValue'], hashlib.sha256(content.encode()).hexdigest())
        self.assertEqual(write['updateTransforms'], [{'fieldPath': 'publishedAt', 'setToServerValue': 'REQUEST_TIME'}])
        self.assertEqual(write['updateMask']['fieldPaths'], ['content', 'contentHash'])

    def test_invalid_input_never_reaches_network(self):
        client = Mock()
        for project, content in [('vma-training', '{}'), ('bad/project', CONTENT)]:
            with self.assertRaises(Exception):
                publisher.publish_workout(client, project, content)
        client.post.assert_not_called()

    def test_unconfirmed_writes_are_not_retried(self):
        for status, body in [(500, {}), (401, {}), (302, {}), (200, {}), (200, {'writeResults': []})]:
            client = Mock()
            client.post.return_value.status_code = status
            client.post.return_value.json.return_value = body
            with self.subTest(status=status, body=body), self.assertRaises(RuntimeError):
                commit_writes(client, 'vma-training', [{}])
            client.post.assert_called_once()
            client.post.return_value.close.assert_called_once()
        client = Mock()
        client.post.side_effect = TimeoutError('private token')
        with self.assertRaises(TimeoutError):
            commit_writes(client, 'vma-training', [{}])
        client.post.assert_called_once()

    @patch('requests.Session')
    @patch('google.auth.default')
    def test_adc_refreshes_before_publication(self, default, session):
        credentials = Mock()
        default.return_value = credentials, 'other-project'
        self.assertIs(authenticated_client('vma-training'), session.return_value)
        default.assert_called_once_with(scopes=['https://www.googleapis.com/auth/datastore'])
        credentials.refresh.assert_called_once()
        credentials.apply.assert_called_once()
        session.return_value.post.assert_not_called()
        credentials.refresh.side_effect = RuntimeError('private token')
        with self.assertRaises(RuntimeError):
            authenticated_client('vma-training')
        session.return_value.close.assert_called_once()

    def test_cli_dry_run_outside_repo_and_utf8(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'workout.json'
            content = CONTENT.replace('\n', '\r\n')
            file.write_bytes(content.encode())
            result = subprocess.run([sys.executable, str(ROOT / 'tool/scripts/publish_workout.py'), '--file', str(file)], cwd=directory, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('Dry run', result.stdout)
            self.assertIn(hashlib.sha256(content.encode()).hexdigest(), result.stdout)
            file.write_bytes(b'\xff')
            result = subprocess.run([sys.executable, str(ROOT / 'tool/scripts/publish_workout.py'), '--file', str(file)], cwd=directory, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)

    @patch('tool.scripts.publish_workout.authenticated_client')
    def test_cli_approval_and_safe_auth_errors(self, authenticate):
        for args in [['--write'], ['--write', '--approve', '--dry-run']]:
            with self.assertRaises(ValueError):
                publisher.main(args)
        authenticate.assert_not_called()
        authenticate.side_effect = RuntimeError('private-token')
        args = ['--file', str(ROOT / 'test/fixtures/workouts/valid.json'), '--write', '--approve']
        with self.assertRaisesRegex(RuntimeError, 'Google authentication failed') as caught:
            publisher.main(args)
        self.assertNotIn('private-token', str(caught.exception))
        authenticate.side_effect = None
        authenticate.return_value.post.side_effect = RuntimeError('private-token')
        with self.assertRaisesRegex(RuntimeError, 'Publication not confirmed'):
            publisher.main(args)
        authenticate.return_value.post.assert_called_once()
        authenticate.return_value.close.assert_called_once()


if __name__ == '__main__':
    unittest.main()
