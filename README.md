# Solar Power Manager

Solar Power Manager is a Flutter app for monitoring inverter and internet
connectivity status, and visualizing power trends over time.

## Features

- Fetches and displays live energy data from a service layer.
- Shows inverter and internet connection status.
- Builds a rolling power chart using `fl_chart`.
- Uses a controller-based architecture to keep UI logic separated.
- Includes unit and widget tests for core flows.

## Project Structure

- `lib/controllers/`: state management and periodic refresh logic.
- `lib/models/`: immutable app models.
- `lib/services/`: data access and external connectivity checks.
- `lib/screens/`: UI screens.
- `lib/widgets/`: reusable UI components.
- `test/`: model, screen, widget, and service tests.

## Requirements

- Flutter SDK (stable channel)
- Dart SDK compatible with `environment.sdk` in `pubspec.yaml`
- Android package id: `com.fabbro.solarpowermanager`

## Local Development

Install dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

Run quality checks locally (same intent as CI):

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

## CI

GitHub Actions validates every push/PR on `master` and `main` with:

- formatting verification
- static analysis
- test execution
- APK build on every `push`
- APK uploaded as workflow artifact
Two automated pipelines keep the project healthy:

**CI — Continuous Integration** (`.github/workflows/ci.yml`)
Runs on every push and pull request to `master`:
- formatting check
- static analysis
- unit tests

**CD — Continuous Delivery** (`.github/workflows/build-release.yml`)
Runs on every version tag (`v*`), after auto-tagging:
- runs tests (safety gate before distributing)
- builds the release APK (split per ABI)
- publishes to one of two GitHub Release channels:

| Channel | Tag on GitHub | When updated |
|---------|---------------|--------------|
| **Stable** | `stable` | `vX.0.0` tags (e.g. `v2.0.0`) |
| **Beta** | `beta` | all other tags (e.g. `v1.0.11`) |

Each update replaces the previous APKs in the channel (no accumulation).

To download: open `Releases` → pick `stable` or `beta` → download the APK matching your device architecture (`arm64-v8a` for most modern phones).

Workflow file: `.github/workflows/build-release.yml`

### Android release signing (required for updatable APKs)

Android allows installing a new APK over an existing one only if both are signed
with the same key and the new APK has a higher `versionCode`.

The release workflow expects these repository secrets:

- `ANDROID_KEYSTORE_BASE64`: base64 of your release keystore file.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: key alias inside the keystore.
- `ANDROID_KEY_PASSWORD`: password for that key alias.

Without these secrets, CI release build fails intentionally to prevent publishing
non-updatable APKs.

## Security and Workflow Hardening

- Actions are pinned to immutable commit SHAs.
- Workflows use minimal job permissions (`contents: read`).
- JavaScript actions are opted into Node 24 runtime using
  `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true`.
