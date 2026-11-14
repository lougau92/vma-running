"""Offline checks using synthetic tokens; never connects to Garmin/keyring."""

import argparse
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from cryptography.fernet import Fernet, InvalidToken
from garminconnect import GarminConnectAuthenticationError, GarminConnectConnectionError

from garmin_auth import authenticated_session
from backend.garmin_sessions import SessionStore


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.key = Fernet.generate_key()
        self.store = SessionStore(self.root, self.key)
        self.args = argparse.Namespace(profile="runner", china=False)

    def test_encrypted_roundtrip_and_permissions(self):
        self.store.save("runner", '{"di_token":"synthetic-secret"}')
        stored = next(self.root.glob("*.enc"))
        self.assertNotIn(b"synthetic-secret", stored.read_bytes())
        self.assertEqual(stored.stat().st_mode & 0o777, 0o600)
        self.assertIn("synthetic-secret", self.store.load("runner"))

    def test_tampering_and_wrong_key_fail_closed(self):
        self.store.save("runner", "synthetic")
        with self.assertRaises(InvalidToken):
            SessionStore(self.root, Fernet.generate_key()).load("runner")
        path = next(self.root.glob("*.enc"))
        path.write_bytes(b"corrupted")
        with self.assertRaises(InvalidToken):
            self.store.load("runner")

    def test_owner_and_region_isolation(self):
        self.store.save("runner", "synthetic")
        self.assertIsNone(self.store.load("other"))
        self.assertIsNone(self.store.load("runner", True))
        self.store.save("other", "other-session")
        self.store._path("other", False).write_bytes(self.store._path("runner", False).read_bytes())
        with self.assertRaisesRegex(ValueError, "identity"):
            self.store.load("other")

    def test_delete_is_idempotent_and_profile_specific(self):
        self.store.save("runner", "one")
        self.store.save("other", "two")
        self.store.delete("runner")
        self.store.delete("runner")
        self.assertIsNone(self.store.load("runner"))
        self.assertEqual(self.store.load("other"), "two")

    def test_failed_replace_keeps_old_session(self):
        self.store.save("runner", "old")
        with patch("backend.garmin_sessions.os.replace", side_effect=OSError):
            with self.assertRaises(OSError):
                self.store.save("runner", "new")
        self.assertEqual(self.store.load("runner"), "old")
        self.assertFalse(list(self.root.glob(".session-*")))

    def test_restores_without_credentials_and_saves_refresh(self):
        self.store.save("runner", "old")
        client = FakeClient()
        with patch("getpass.getpass", side_effect=AssertionError("Must not prompt")):
            with authenticated_session(self.args, store=self.store, factory=lambda **_: client):
                self.assertEqual(client.loaded, "old")
                client.serialized = "refreshed"
        self.assertEqual(self.store.load("runner"), "refreshed")

    def test_network_failure_preserves_session_without_prompt(self):
        self.store.save("runner", "old")
        client = FakeClient(GarminConnectConnectionError("offline"))
        with patch("getpass.getpass", side_effect=AssertionError("Must not prompt")):
            with self.assertRaises(GarminConnectConnectionError):
                with authenticated_session(self.args, store=self.store, factory=lambda **_: client):
                    self.fail("Network failure should propagate")
        self.assertEqual(self.store.load("runner"), "old")

    def test_rejected_session_reauthenticates_and_saves(self):
        self.store.save("runner", "expired")
        clients = iter([FakeClient(GarminConnectAuthenticationError("expired")), FakeClient()])
        with patch("sys.stdin.isatty", return_value=True), patch("getpass.getpass", side_effect=["email", "password"]):
            with authenticated_session(self.args, store=self.store, factory=lambda **_: next(clients)) as client:
                self.assertIsNone(client.loaded)
        self.assertEqual(self.store.load("runner"), "new-session")

    def test_upload_error_still_preserves_refreshed_session(self):
        self.store.save("runner", "old")
        with self.assertRaisesRegex(RuntimeError, "upload"):
            with authenticated_session(self.args, store=self.store, factory=lambda **_: FakeClient()):
                raise RuntimeError("upload")
        self.assertEqual(self.store.load("runner"), "new-session")


class FakeClient:
    def __init__(self, error=None):
        self.client = self
        self.password = None
        self.loaded = None
        self.serialized = "new-session"
        self.error = error

    def login(self, saved=None):
        self.loaded = saved
        if self.error:
            raise self.error

    def dumps(self):
        return self.serialized


if __name__ == "__main__":
    unittest.main()
