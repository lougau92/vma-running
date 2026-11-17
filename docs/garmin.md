# Garmin export in Flutter

The app uses the separate [garmin-proxy service](https://github.com/lougau92/garmin-proxy).
The PWA sends its existing anonymous Firebase ID token; the proxy keeps Garmin
sessions encrypted. Passwords and MFA codes are held only for the login request,
never saved in app preferences. Clearing browser storage or changing devices can
lose the anonymous identity and access to its Garmin connection.

## Configure and run

Follow the proxy repository's local setup instructions, using the same Firebase
project as this app (`vma-training`). Start the proxy on port 8080 and include
`http://localhost:8081` in its `ALLOWED_ORIGINS`. Run Flutter at that fixed origin:

```sh
flutter run -d chrome --web-hostname localhost --web-port 8081 \
  --dart-define=GARMIN_PROXY_URL=http://localhost:8080
```

The production URL must use HTTPS. For GitHub Pages, set the repository Actions
variable `GARMIN_PROXY_URL` to the deployed proxy URL and allow the origin
`https://lougau92.github.io` in the proxy. The variable is public configuration,
not a secret. The existing deployment version gate still applies. No URL means
Garmin is unavailable in that build; other app features keep working.

Cloud deployment is separate and has not been performed by this change.

## Use

1. Open **Settings → Garmin Connect** to sign in, complete MFA if needed, or
   disconnect. A saved-session status does not guarantee Garmin still accepts it;
   the next request checks that.
2. Select a workout and group, then choose **Export to Garmin**.
3. Resolve alternatives and duration/distance/lap-count ranges. Optional blocks
   default to included. Repetition ranges use the maximum. Lap length defaults
   to 400 m only when the plan does not specify one.
4. Check the preview and warnings, then **Save to Garmin Connect**.
5. Optionally choose **Send to watch**. Select a watch when several qualify.
   “Delivery requested” means queued by Garmin; sync the watch through Garmin
   Connect to receive it.

Export uses the saved VMA for numeric VMA targets. Speed and pace ranges become
Garmin pace alerts. Other targets, including progressions, are preserved as
instructions with an explicit warning that they have no automated watch alerts.
Manual LAP is supported. Event, unknown, repetition-count and compound end
conditions block export. Unspecified warmup/cooldown phases are not invented.
Expanded workouts are limited to 200 steps by the proxy. Long descriptions are
shortened with a preview warning. The source workout is never modified.

## Interrupted requests

The local journal stores workout snapshots, operation IDs and Garmin workout IDs,
scoped to the Firebase UID. It contains no login credentials or session tokens.
It is saved before sending requests. Resume an interrupted export from **Recent
exports / resume**. Retrying the same snapshot uses its original idempotency key;
watch delivery uses a different saved key and never re-uploads the workout.
An already completed export is reused. **Create another copy** explicitly creates
a fresh upload after confirmation.

If Garmin's response was ambiguous, check Garmin Connect first. The proxy blocks
unsafe replay rather than guessing whether Garmin received the write. There is
no automatic offline/background export queue. API responses bypass the service
worker cache. Disconnect removes the backend session but keeps operation history.

## Verification

```sh
flutter analyze
flutter test
flutter build web --release --base-href /vma-running/ \
  --dart-define=GARMIN_PROXY_URL=https://your-proxy.example
```

To validate actual Dart output against the Python proxy's payload model:

```sh
GARMIN_CONTRACT_OUTPUT=/tmp/garmin-export-contract.json \
  flutter test test/garmin_export_test.dart
```

Then, in the proxy checkout:

```sh
uv run python -c 'import json; from proxy.models import Workout; Workout.model_validate(json.load(open("/tmp/garmin-export-contract.json"))); print("Valid")'
```

Automated tests use fake Garmin responses and create no live workouts. For a
manual end-to-end test, connect from Settings, export one reviewed workout, reload
the app and reopen the same export to verify it is reused, then request delivery
and sync the watch. Confirm the workout exists only once in Garmin Connect.
