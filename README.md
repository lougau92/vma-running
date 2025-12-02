# VMA Running Companion

VMA-focused training helper built with Flutter. Enter your VMA once, then explore target paces, predicted times, and a structured training plan that scales to your intensity.

## Features
- VMA input with persistence (stored via `SharedPreferences`); guided prompt on first launch.
- Intensity tab: pace table across customizable %VMA and a configurable reference distance.
- Times tab: predicted splits for distance or time ranges with adjustable intensity slider.
- Training plan tab: loads an interval plan from GitHub with disk/memory caching and shows reps, pace targets, and recoveries by group.
- Settings: language (EN/FR/NL), theme (light/dark/system), and default distance/time ranges.

## Quick start
1) Install Flutter (Dart 3.9+ / Flutter 3.24+ recommended).  
2) Fetch deps: `flutter pub get`  
3) Run: `flutter run -d chrome` (or any connected device)  
4) Tests: `flutter test`

## Training plan data
- Default source: see `configUrl` in `lib/vma_training_plan.dart` (currently points to GitHub). The loader caches responses in a temp `github_cache` folder and falls back to stale data if offline. Update this URL to a raw JSON endpoint you control.
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
- Training plan not loading: ensure network access to the configured URL or point `configUrl` to a reachable/raw JSON. Clear cached plans via `AdvancedGitHubCacheManager.clearCache()` if you need to force a refresh.
- Pace tables empty: set your VMA from the top banner; the app will prompt on first use.
