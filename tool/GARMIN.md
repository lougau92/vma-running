# Garmin connection smoke test

For live workout-format discoveries, see [the payload reference](GARMIN_PAYLOAD.md).

This standalone experiment uses the unofficial
[python-garminconnect](https://github.com/cyberjunky/python-garminconnect)
client. It signs in, handles MFA when requested, and lists device display names.
It does not create workouts, request watch delivery, or change the Flutter app.
Login also reads the profile/settings required by the library.

From the repository root, with Python 3.12+ and `uv` installed:

```sh
uv venv --python python3.12 .tools/garmin-venv
uv pip install --python .tools/garmin-venv/bin/python -r tool/garmin-requirements.txt
.tools/garmin-venv/bin/python tool/garmin_connection_test.py
```

Dependencies are installed on this checkout. Enter your email, password, and
MFA code at the hidden prompts on the first run, never in chat or command
arguments. Use `--china` for a Garmin China account. Later runs restore the
encrypted session automatically, including when switching between the connection
and upload scripts. `GARMINTOKENS` is ignored: no plaintext token file is used.

## Encrypted session persistence

`backend/garmin_sessions.py` provides authenticated encryption and a local
filesystem adapter. Encrypted tokens live under the ignored `.tools/garmin-sessions/`
directory in files created with mode 0600. The encryption key is generated once
and stored separately in the desktop Secret Service keyring under service
`vma-running.garmin`, entry `session-encryption-key-v1`. The password is never
saved. The keyring must be available and unlocked; there is no plaintext fallback.
If unavailable, ensure your Linux desktop Secret Service (e.g. GNOME Keyring)
is installed/running and unlocked before retrying.

Use `--profile NAME` with either script for a separate local account. Profiles
and Garmin China sessions are isolated. Run only one script per profile at a
time to avoid concurrent session refreshes. Refreshed tokens are saved after
login and after operations, including failed uploads. Network errors keep the
saved session; an explicit authentication rejection asks you to reconnect.
Corrupt sessions or missing/wrong keys fail closed. If the key is lost, forget
the old session and log in again.

Delete a profile's saved session without logging into Garmin:

```sh
.tools/garmin-venv/bin/python tool/garmin_connection_test.py --forget-session
```

Add the same `--profile` and `--china` options used when connecting. This deletes
our local copy, not Garmin's server session. It does not revoke stolen tokens.
Anyone controlling the running process or unlocked desktop may still use the
session. Encryption protects copied storage, not a compromised runtime.

For deployment, supply encryption keys through a server secret manager and
replace the local filesystem adapter with persistent server storage. Derive
session owners from verified anonymous Firebase ID tokens, never a browser's
claimed owner/profile. No HTTP endpoints, Firebase verification, expiry cleanup,
distributed locking, or cloud deployment are implemented in this local step.
The CLI keyring adapter is only for development; keep Garmin session plaintext
and encryption keys out of PWA assets and browser storage.

Offline verification (synthetic tokens only):

```sh
.tools/garmin-venv/bin/python -m unittest discover -s tool -p 'test_garmin_sessions.py'
```

Two PASS messages establish that login and authenticated device lookup work
from this machine. An empty device list still establishes cloud connectivity,
but does not verify watch pairing. This test cannot establish workout creation,
watch compatibility, or delivery; those require a separate upload experiment.
Failures return a nonzero exit code and suppress raw server responses. Avoid
repeated attempts after a rate limit or authentication failure.

## Upload a small test workout

```sh
.tools/garmin-venv/bin/python tool/garmin_upload_test.py --preview
.tools/garmin-venv/bin/python tool/garmin_upload_test.py --send-to-watch
```

The second command asks for confirmation and hidden credentials, creates
`VMA Connection Test - 3 min` (one minute each of warmup, easy running, and
cooldown, without pace targets), and requests delivery to the registered
running-capable watch. Omit `--send-to-watch` to upload only. Nothing is scheduled on your
calendar. The script prints the workout ID and Garmin Connect link before
requesting delivery. Sync your watch with Garmin Connect and check its running
workouts; accepting the delivery request does not prove the watch received it.
You can also open the link and choose Send to Device manually.

Each invocation creates a new workout. If a request fails, check Garmin Connect
before retrying to avoid duplicates. Delete the workout from Garmin Connect
when finished (and from the watch separately if it remains there).

To retry delivery of an existing workout without creating a duplicate:

```sh
.tools/garmin-venv/bin/python tool/garmin_upload_test.py --workout-id 1760106415
```

This mode implies `--send-to-watch`. Add `--device-id ID` to choose among multiple
registered running-capable watches. The script refuses ambiguous selections or
devices that cannot receive running workouts. It avoids Garmin's last-used
device lookup, which returned an old Edge 810 absent from this account's
registered devices during debugging.

Delivery errors identify the failing stage without printing raw responses.
The delivery adapter POSTs a list to `/device-service/devicemessage/messages`.
Live verification on 2026-11-12: workout 1760106415 was accepted for the fenix 3 HR
with message status `new`. The alternative single-object request mentioned in
upstream documentation returned HTTP 500 (`MismatchedInputException`); it is not
used. Queue acceptance does not verify physical receipt: sync the watch and
check its running workouts. Run all offline Garmin checks with:

```sh
.tools/garmin-venv/bin/python -m unittest discover -s tool -p 'test_garmin_*.py'
```
