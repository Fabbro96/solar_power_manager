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
- APK uploaded as CI workflow artifact on every push.

Workflow file: `.github/workflows/ci.yml`

To download the APK:

1. Open `Releases` on GitHub.
2. **Beta** (tag: `beta`): updated on every tag push — latest changes, may be unstable.
3. **Stable** (tag: `stable`): updated only for `vX.0.0` tags — major, vetted releases.
4. Look for files named like `solar-power-manager-1.0.10--build-10-arm64-v8a.apk`.
5. Or open the CI run `Artifacts` section for intermediate builds.

## Release Build

Tag pushes matching `v*` trigger the Android APK build workflow:
- `vX.0.0` (minor=0, patch=0) → published to the `stable` release.
- All other tags → published to the `beta` release.

Each channel keeps only the latest APKs (previous assets are removed on every update).

Workflow file: `.github/workflows/build-release.yml`

## Security and Workflow Hardening

- Actions are pinned to immutable commit SHAs.
- Workflows use minimal job permissions (`contents: read`).
- JavaScript actions are opted into Node 24 runtime using
  `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true`.
