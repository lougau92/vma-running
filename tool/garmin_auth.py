"""Local CLI adapter around the reusable encrypted backend session store."""

from contextlib import contextmanager
import getpass
import logging
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend.garmin_sessions import SessionStore


class SessionStorageError(RuntimeError):
    """Safe user-facing storage failure without token or key details."""


def add_session_arguments(parser):
    parser.add_argument("--profile", default="default", help="Local session profile (default: default)")
    parser.add_argument("--forget-session", action="store_true", help="Delete this profile's saved session and exit")


def local_store() -> SessionStore:
    from cryptography.fernet import Fernet
    # Explicitly select Secret Service rather than accepting an installed
    # third-party keyring backend that could store secrets in plaintext.
    from keyring.backends.SecretService import Keyring

    try:
        keyring = Keyring()
        key = keyring.get_password("vma-running.garmin", "session-encryption-key-v1")
        if key is None:
            key = Fernet.generate_key().decode("ascii")
            keyring.set_password("vma-running.garmin", "session-encryption-key-v1", key)
    except Exception:
        raise SessionStorageError("Unlock your desktop Secret Service keyring; no plaintext fallback is allowed.") from None
    return SessionStore(Path(__file__).resolve().parents[1] / ".tools/garmin-sessions", key.encode("ascii"))


def forget_session(args) -> bool:
    if not args.forget_session:
        return False
    local_store().delete(args.profile, args.china)
    print("Saved session deleted locally. This does not revoke tokens at Garmin.")
    return True


@contextmanager
def authenticated_session(args, *, store=None, factory=None):
    """Restore a saved session, or prompt once; persist refreshes on exit."""
    from garminconnect import Garmin, GarminConnectAuthenticationError

    logging.disable(logging.CRITICAL)
    os.environ.pop("GARMINTOKENS", None)
    store = store if store is not None else local_store()
    factory = factory if factory is not None else Garmin
    client = None
    try:
        saved = store.load(args.profile, args.china)
    except Exception:
        raise SessionStorageError("Saved session cannot be read. Check storage/keyring access, or use --forget-session and connect again.") from None
    if saved is not None:
        client = factory(is_cn=args.china, retry_attempts=1)
        try:
            client.login(saved)
            print("Restored saved Garmin session.")
        except GarminConnectAuthenticationError:
            store.delete(args.profile, args.china)
            client = None
            print("Garmin rejected the saved session. Please connect again.")
        # Network/rate-limit errors propagate; they do not discard saved tokens.
    if client is None:
        if not sys.stdin.isatty():
            raise RuntimeError("First login requires your own interactive terminal.")
        print("Session tokens will be encrypted; your password will not be saved.")
        email = getpass.getpass("Garmin email (hidden): ").strip()
        password = getpass.getpass("Garmin password (hidden): ")
        if not email or not password:
            raise ValueError("Email and password are required")
        client = factory(
            email=email, password=password, is_cn=args.china,
            prompt_mfa=lambda: getpass.getpass("Garmin MFA code (hidden): ").strip(),
            retry_attempts=1,
        )
        password = None
        try:
            client.login()
        finally:
            client.password = None
        print("Garmin login succeeded.")
    # Persist immediately so an upload failure does not lose a new login.
    try:
        store.save(args.profile, client.client.dumps(), args.china)
    except Exception:
        raise SessionStorageError("Could not persist the Garmin session; check local storage access before retrying.") from None
    try:
        yield client
    finally:
        try:
            store.save(args.profile, client.client.dumps(), args.china)
        except Exception:
            # Do not mask an upload error or suggest retrying an upload that
            # already succeeded. The next run may require login again.
            print("WARNING: Could not save refreshed Garmin session; reconnecting may be required.")
        client.password = None
