# VMA Running Companion

VMA-focused training helper built with Flutter. Enter your VMA once, then explore target paces, predicted times, and a structured training plan that scales to your intensity.

## Features
- VMA input with persistence (stored via `SharedPreferences`); guided prompt on first launch.
- Intensity tab: pace table across customizable %VMA and a configurable reference distance.
- Times tab: predicted splits for distance or time ranges with adjustable intensity slider.
- Training plan tab: loads an interval plan from Firestore with local caching and shows reps, pace targets, and recoveries by group.
- Export: copy the selected training-plan group to the clipboard.
- Settings: language (EN/FR/NL), theme (light/dark/system), and default distance/time ranges.
- Offline-first: ships a service worker that caches the app shell so core features load without network; training plan data reuses cached responses if offline.

## Quick start
1) Install Flutter (Dart 3.9+ / Flutter 3.24+ recommended).  
2) Fetch deps: `flutter pub get`  
3) Run: `flutter run -d chrome` (or any connected device)

## Firebase configuration

VMA content uses the `vma-training` Firebase project on web, Android, and iOS.
Firebase initializes before the first remote content read, using the public
platform options in `lib/firebase_options.dart`. Backend initialization or
sign-in failures keep cached/bundled content and pace calculations usable.
To regenerate them after signing in with `firebase login`, run:

```sh
"$HOME/.pub-cache/bin/flutterfire" configure --project=vma-training --platforms=android,ios,web
```

If `flutterfire` is not on your PATH, the full path above works. Alternatively,
add `export PATH="$PATH:$HOME/.pub-cache/bin"` to your shell configuration.
Web, Android (`com.example.vma_running`), and iOS
(`com.example.flutterApplication1`) are configured using the existing app IDs.
Restart `flutter run -d chrome` for web, or select a connected Android/iOS device
with `flutter devices` and `flutter run -d <device-id>`. Android needs the Android
SDK command-line tools and accepted licenses; iOS needs macOS and Xcode.

Content lives in the `app_documents` collection: `training_plan`,
`club_communications`, and `challenge_classement`. Each document has a `content`
string containing its JSON or CSV payload. Enable Cloud Firestore and create its
default database in Firebase Console, then create the documents and configure
Firestore rules for the intended readers; client writes are not needed by VMA.
Firebase client options are public configuration, not admin credentials.
Before a remote content read, VMA reuses a persisted Firebase session or signs in
anonymously. This happens without a login screen and works on web, Android, and
iOS. Concurrent reads share one sign-in attempt; failures retain the existing
cached/bundled fallback and can be retried on refresh. Enable the Anonymous
provider in Firebase Authentication for `vma-training`.

`firestore.rules` requires an authenticated Firebase session for individual reads
of the three content documents. Client writes, collection listing, and all other
paths are denied. Anonymous sessions can be obtained by anyone; this controls
session access rather than club membership. Supabase feedback sessions are
independent.

Deploy these rules with:

```sh
firebase deploy --only firestore:rules --project=vma-training
```
Feedback uses its separate Supabase backend described below.

### Content loading, retries, and refresh

- Opening any of the three content screens immediately shows the last downloaded
  version (memory or device/browser storage), or the bundled file on a first run.
  A server read then updates the visible content in the background.
- Each refresh allows at most **3 attempts**, with delays of **500 ms** and
  **1 second** after transient Firebase errors (`unavailable`,
  `deadline-exceeded`, `aborted`, or `network-request-failed`). Permission,
  configuration, and missing-content errors are not retried.
- The busy indicator stops after **12 seconds**, keeping local content visible
  and explaining when cached/bundled data is being used. No further app retry
  starts beyond that budget. Firebase has its own transport retry behavior.
- A Dart timeout cannot cancel a Firebase request. Any unfinished read remains
  shared by subsequent refreshes; if it succeeds late, the open screen and local
  cache update automatically. This prevents overlapping reads after a timeout.
- Use the visible refresh button on desktop/mobile or pull down on mobile.
  Refreshing keeps the displayed content in place. Reopening a content screen
  also checks the server. There is no periodic polling or cache expiry: saved
  content stays available offline; after all attempts fail, refresh or reopen
  the screen to try again.
- Firebase anonymous sessions persist and are reused. A failed sign-in can retry
  under the same policy. Local cache storage failures do not discard a successful
  server response. Club communications remain encrypted in persistent storage;
  decrypted messages stay in memory and are refreshed with the encrypted payload.
  The plaintext `raw_messages.json` source is excluded from the app bundle.

### Troubleshooting remote content

In a debug run, a fallback also logs `Remote content load failed (...)` with
only the Firebase plugin and error code. No token, document content, or raw
exception message is logged. For example, `firebase_auth/network-request-failed`
indicates the sign-in request failed, while `cloud_firestore/permission-denied`
indicates Firestore rejected the read. Expand the `@firebase/firestore` warning
in Chrome DevTools to see any browser transport error. A fallback alone does
not mean the documents are absent; the app also uses bundled files when offline.

## Publishing content to Firestore

Use Node 24 and `npm ci`, then sign in once with `firebase login` (or
`npm exec -- firebase login`). The publisher reuses that CLI login; no service
account key or token is added to the repository. The Firebase CLI Node library is
pinned because the authentication adapter uses its internal APIs.

Preview the bundled files and target project without authentication or network:

```sh
npm run content:publish
```

Publish all three documents, or only the training plan:

```sh
npm run content:publish -- --write
npm run content:publish -- --write --only training_plan
```

`--dry-run` is also accepted explicitly. The project defaults to `vma-training`; `--project PROJECT_ID` overrides it.
The script resolves source files relative to the repository, validates all
selected files before authenticating, and stores their original UTF-8 text in
`app_documents/<id>.content` in the `(default)` database. It uploads
`training_plan`, `club_communications` (encrypted `messages.json`, never the raw
message file), and `challenge_classement` using one atomic commit. Existing
`content` values are replaced; other fields are preserved. Files must be at most
1,000,000 UTF-8 bytes each. Failed requests are not automatically retried.

Create the default Firestore database once in Firebase Console before publishing.
The publisher does not create databases or deploy access rules. Uploading with
an administrator login does not grant the app permission to read: configure
Firestore rules for the intended readers separately. Run `npm run test:content`
to check validation and publishing behavior without touching a live database.

## Release feature flags

Club communications and club rankings are disabled by default. Build-time flags
control both navigation and page creation: disabled pages do not load their data.
These are release switches, not user preferences or access controls. To enable
one or both in a development run or a custom build:

```sh
flutter run -d chrome --dart-define=ENABLE_CLUB_COMMUNICATIONS=true --dart-define=ENABLE_CLUB_RANKINGS=true
```

The same flags work with `flutter build web`. The main deployment uses the
defaults (both disabled). Navigation uses stable page identifiers, so flags do
not change which page an existing tab selection represents.

The previous Intervals.icu/Garmin integration is preserved on the local
`feature/intervals-icu` branch. Main contains clipboard export only and no longer
reads or writes Intervals.icu credentials. Previously saved credentials remain
in device storage, unused.

## Service worker offline/online switch test
1) Run web build: `flutter run -d chrome` (or `flutter build web && npx serve build/web`).
2) Load once online so the service worker installs and caches assets (including `assets/training_plans/training_example.json`).
3) In DevTools → Application → Service Workers, confirm it is “activated”.
4) In DevTools → Network, toggle “Offline” and reload:
   - App shell should load from cache.
   - Training plan should come from the cached example JSON.
   - Console should not spam font errors (fonts are cached with a graceful fallback).
5) Toggle “Offline” off and reload to confirm it resumes normal online fetching.

### Automated local SW test (same as CI)
1) Build web: `flutter build web --release`
2) Install test deps: `npm install playwright@1.41.2 http-server && npx playwright install --with-deps chromium`
3) Run: `node tool/sw-offline-test.js`
   - Starts a local server, waits for the service worker, goes offline, checks the cached training plan, and asserts no font error spam.

## Training plan data
- Default source: Firestore document `app_documents/training_plan`, with the plan JSON stored in a string field named `content`. The loader shows cached data or the bundled example immediately, then revalidates against the server with the bounded policy above.
- Local example: `assets/training_plans/training_example.json` shows the schema. Each plan includes `warmup`, `cooldown`, `remarks`, and `groups` with `blocks` of interval `sets` (reps, distance or duration, `%VMA`, recovery, and recovery type).

## Localization & theming
- Strings live in `lib/l10n/translations_*.dart`; add languages by creating another translation file and wiring it in `AppLocalizations`.
- Themes are defined in `lib/theme.dart`; choose light/dark/system in the settings page.

## Persistence & settings
- VMA value is stored in `lib/vma_storage.dart`.
- App preferences (locale, theme, times/distances bounds) are handled in `lib/settings_storage.dart` and edited via the settings page.

## Assets
- Logos live under `assets/enjambee_img/`; training plans under `assets/training_plans/`. Add new assets and list them in `pubspec.yaml`.

## Troubleshooting
- Training plan not loading: check Firebase initialization, the `app_documents/training_plan` document and its `content` string, and the Firestore rules for the intended reader. A failed remote read uses cached or bundled data.
- Pace tables empty: set your VMA from the top banner; the app will prompt on first use.

## User feedback

The home app bar and settings page include a feedback button. The form follows
the app language (EN/FR/NL) and submits only the entered message, category, and
optional reply email, plus an automatic snapshot of the active UI taken before
the form opens. It records route/dialog context, app version, locale/theme,
viewport/text scale, active navigation, visible controls, table dimensions and
scroll positions. Reusable screen/section scopes add the displayed VMA/ranges,
Times table mode, selected workout group and cache/network source. The opening
snapshot is preserved during edits and retries. Inputs, document text, browser
URLs, passwords and screenshots are excluded. It uses the standalone `app_feedback` Git dependency,
pinned to a reviewed commit in `pubspec.yaml`. The ignored local
`pubspec_overrides.yaml` points to `../app-feedback`, so shared changes appear
without copying. Run `flutter pub get` after changing dependency configuration.
Clean CI uses the pinned remote revision; publish the shared repository and add
a read-only `APP_FEEDBACK_DEPLOY_KEY` Actions secret for its private checkout.
Never paste that key into source or chat.

`assets/feedback.json` contains intentionally public Supabase client settings;
never use secret or service-role keys there. An anonymous session is created
only on first feedback submission, independently of the app's Firebase setup.
Feedback needs a network connection; the rest of the app remains usable offline.
The shared backend stores this app's submissions under `app_id = vma-running`;
clients can insert their own feedback and cannot read the inbox.

Agents can review only this inbox with
`dart run app_feedback:feedback` using the
non-secret root `feedback.config.json` and the existing Supabase CLI login.
The skill documents setup and date filtering without exposing admin keys.

Account-free submission requires anonymous sign-ins to be enabled on the shared
Supabase project. `supabase/config.toml` manages only that flag; use CLI 3+
`config diff` to review it before any authorized `config push`. All other remote
auth settings are undeclared and preserved.

### Runtime environment and mobile refresh

The app detects device class independently of window size. Android and iOS
(including iPadOS desktop-site mode) use pull-to-refresh on the training plan,
rankings, and club communications; their refresh buttons are hidden. Desktop
browsers and desktop PWAs keep the button, even in a narrow window.

Feedback context includes platform, mobile/desktop class, web/native runtime,
and the current browser display mode. Web presentation comes from the
[`display-mode`](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/display-mode) media query with the iOS `navigator.standalone` fallback and
updates when presentation changes. This describes the current window, not
whether the app is installed elsewhere; fullscreen alone does not prove PWA
installation. Device classification is best-effort when browsers spoof their
platform. Raw user agent strings are not collected.

### Live running calculator

The Calculator tab derives distance (km), elapsed time, speed (km/h), pace
(min:sec/km), and VMA percentage from two independent known quantities.
Choose distance + time, distance + speed/pace/intensity, or time +
speed/pace/intensity in either order. VMA percentage uses the saved VMA, which
can be edited from the calculator. General speed/pace calculations also work
without a VMA.

Decimal commas and dots are accepted. Time accepts `mm:ss`, `h:mm:ss`, or bare
seconds; pace accepts `min:sec` or bare seconds per km. Results update while
typing and disappear for incomplete or invalid inputs. Input pairs persist
when switching tabs during the current app session. Feedback records the
chosen measure types; typed calculator input is excluded from UI capture.

### Shared running calculations

`lib/running/running.dart` exposes the Dart-only backbone used by
the calculator, VMA intensity table, Times table, and workout display/export.
`RunningSpeed` converts km/h, seconds per km, and VMA percentage; it creates a
`RunningSplit` for either a distance or duration. Internally, distances are
meters and times are seconds. Invalid, nonfinite, or unrepresentable values
return `null`. Results retain full precision until display formatting.

Calculator field handling and input-pair selection stay in
`lib/calculator/running_calculator_draft.dart`. Table presets and row selection
stay with the tables. Shared duration parsing and pace/duration formatting live
in `lib/running/running_time.dart`, so the screens and clipboard export use the
same rounding and clock notation.

Distance constants, parsing, and numeric formatting live in
`lib/running/running_distance.dart` and are exported by the same backbone entry
point. Localized labels and the `BuildContext` extension live in
`running_distance_labels.dart`, a separate Flutter adapter, keeping the core
independent of Flutter and application localization.
