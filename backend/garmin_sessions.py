"""Encrypted Garmin sessions with caller-supplied keys and owner identities.

The local filesystem adapter is for development. A deployed service must derive
the owner from verified Firebase authentication, and obtain keys from a server
secret manager. It must not expose session plaintext through an API.
"""

import hashlib
import json
import os
from pathlib import Path
import tempfile

from cryptography.fernet import Fernet


class SessionStore:
    """Authenticated encryption; binds each session to its owner and region."""

    def __init__(self, directory: Path, key: bytes):
        self.directory = directory
        self.cipher = Fernet(key)

    def _path(self, owner: str, china: bool) -> Path:
        if not owner:
            raise ValueError("A session owner is required")
        digest = hashlib.sha256(json.dumps([owner, china]).encode()).hexdigest()
        return self.directory / f"{digest}.enc"

    def load(self, owner: str, china: bool = False) -> str | None:
        path = self._path(owner, china)
        try:
            with path.open("rb") as stream:
                encrypted = stream.read()
        except FileNotFoundError:
            return None
        record = json.loads(self.cipher.decrypt(encrypted))
        if (record.get("version"), record.get("owner"), record.get("china")) != (1, owner, china):
            raise ValueError("Session identity mismatch")
        session = record["session"]
        if not isinstance(session, str):
            raise ValueError("Invalid session")
        return session

    def save(self, owner: str, session: str, china: bool = False) -> None:
        path = self._path(owner, china)
        encrypted = self.cipher.encrypt(json.dumps({
            "version": 1, "owner": owner, "china": china, "session": session,
        }).encode())
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        # Only ciphertext touches disk; atomic replacement leaves the prior
        # session intact if a write fails. mkstemp creates files with mode 0600.
        descriptor, temporary = tempfile.mkstemp(dir=self.directory, prefix=".session-")
        try:
            with os.fdopen(descriptor, "wb") as stream:
                stream.write(encrypted)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
        finally:
            Path(temporary).unlink(missing_ok=True)

    def delete(self, owner: str, china: bool = False) -> None:
        self._path(owner, china).unlink(missing_ok=True)
