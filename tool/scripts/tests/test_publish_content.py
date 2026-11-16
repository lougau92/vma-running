"""Content publishing regression tests; no remote writes."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
from tool.scripts.publish_content import ROOT, SOURCES, load_content, validate_content, commit_body, publish, main


class ContentPublisherTests(unittest.TestCase):
    def test_assets_preserve_exact_bytes(self):
        documents = load_content()
        self.assertEqual(len(documents), 2)
        for document in documents:
            self.assertEqual(document['content'].encode(), (ROOT / SOURCES[document['id']]).read_bytes())

    def test_atomic_commit_preserves_other_fields(self):
        documents = load_content()
        client = Mock()
        client.post.return_value.status_code = 200
        client.post.return_value.json.return_value = {'writeResults': [{}, {}]}
        publish(client, 'vma-training', documents)
        client.post.assert_called_once()
        writes = client.post.call_args.kwargs['json']['writes']
        self.assertEqual(len(writes), 2)
        for document, write in zip(documents, writes):
            self.assertEqual(write['update']['name'], 'projects/vma-training/databases/(default)/documents/app_documents/' + document['id'])
            self.assertEqual(write['update']['fields'], {'content': {'stringValue': document['content']}})
            self.assertEqual(write['updateMask'], {'fieldPaths': ['content']})

    def test_invalid_payloads_and_targets(self):
        raw = (ROOT / 'assets/communications/raw_messages.json').read_text()
        for document_id, content in [('club_communications', raw), ('club_communications', '{'), ('club_communications', '{}'), ('club_communications', '[]'), ('club_communications', ' '), ('club_communications', 'é' * 500001), ('challenge_classement', 'wrong,header'), ('unknown', '{}')]:
            with self.subTest(document_id=document_id, content=content[:10]), self.assertRaises(ValueError):
                validate_content(document_id, content)
        for ids in [[], ['raw_messages']]:
            with self.assertRaises(ValueError):
                load_content(ids)
        for project in [None, '', 'bad/project', 'UpperCase']:
            with self.assertRaises(ValueError):
                commit_body(project, [])
        self.assertEqual([d['id'] for d in load_content(['club_communications'])], ['club_communications'])

    def test_invalid_batch_never_publishes(self):
        documents = load_content()
        documents[1]['content'] = 'wrong,header'
        client = Mock()
        with self.assertRaises(ValueError):
            publish(client, 'vma-training', documents)
        client.post.assert_not_called()
        with tempfile.TemporaryDirectory() as directory:
            for document_id, file in SOURCES.items():
                target = Path(directory) / file
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b'{}' if document_id == 'club_communications' else (ROOT / file).read_bytes())
            with self.assertRaises(ValueError):
                load_content(directory=directory)

    def test_cli_outside_repository_without_authentication(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(ROOT / 'tool/scripts/publish_content.py')], cwd=directory, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Dry run', result.stdout)
        self.assertIn('Project: vma-training', result.stdout)

    @patch('tool.scripts.publish_content.authenticated_client')
    def test_conflicting_flags_and_safe_failures(self, authenticate):
        with self.assertRaisesRegex(ValueError, 'Choose --write'):
            main(['--write', '--dry-run'])
        authenticate.assert_not_called()
        authenticate.side_effect = RuntimeError('private-token')
        with self.assertRaisesRegex(RuntimeError, 'authentication failed'):
            main(['--write'])
        authenticate.side_effect = None
        authenticate.return_value.post.side_effect = TimeoutError('private-token')
        with self.assertRaisesRegex(RuntimeError, 'Publication not confirmed') as error:
            main(['--write'])
        self.assertNotIn('private-token', str(error.exception))
        authenticate.return_value.post.assert_called_once()
        authenticate.return_value.close.assert_called_once()


if __name__ == '__main__':
    unittest.main()
