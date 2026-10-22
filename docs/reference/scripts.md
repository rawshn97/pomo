# Reference: Tooling and Build Scripts

This document details all operational and build scripts available in `scripts/` and the repository root.

---

## 1. Quick Reference

| Script | Purpose | Output / Artifact |
|---|---|---|
| [`./scripts/setup.sh`](#setup-sh) | Install dependencies and generate l10n code | Updated `.dart_tool/` and `app_localizations.dart` |
| [`./scripts/verify.sh`](#verify-sh) | Format check, static analysis, unit/widget tests | Exit code 0 on clean pass |
| [`./scripts/build-web.sh`](#build-web-sh) | Build CanvasKit Web PWA for Vercel | `deploy/` and `deploy/focus/` |
| [`./scripts/build_android_apk.sh`](#build-android-apk-sh) | Build unsigned debug APK for testing | `app-production-debug.apk` |
| [`./scripts/build_android_release_apk.sh`](#build-android-release-apk-sh) | Build signed production release APK | `app-production-release.apk` |
| [`./scripts/deploy_android_update.sh`](#deploy-android-update-sh) | Build, GitHub release, and update OTA manifest | Tag `v<version>`, `version.json`, uploaded APK |
| [`./scripts/setup-macos-signing.sh`](#setup-macos-signing-sh) | Configure ad-hoc signing for macOS notifications | Signed debug/release macos entitlements |
| [`./scripts/generate-sounds.py`](#generate-sounds-py) | Synthesize alert audio WAV files | `assets/sounds/*.wav` |
| [`./build_macos_dmg.sh`](#build-macos-dmg-sh) | Compile macOS app and package DMG | `./Pomo.dmg` |

---

## 2. Script Details

### `setup.sh`

**Path:** `scripts/setup.sh`  
**Description:** Prepares a fresh checkout by resolving Flutter dependencies and generating localized string accessors.

```bash
./scripts/setup.sh
```

**Actions performed:**
- Runs `flutter pub get`.
- Runs `flutter gen-l10n --arb-dir="lib/l10n/arb"`.

---

### `verify.sh`

**Path:** `scripts/verify.sh`  
**Description:** Complete pre-commit and pre-deployment quality validation gate.

```bash
./scripts/verify.sh
```

**Actions performed:**
1. Code formatting check: `dart format --output=none --set-exit-if-changed lib/ test/ scripts/`
2. Static analysis: `flutter analyze` enforcing `very_good_analysis` rules.
3. Automated test suite: `flutter test --flavor development` across all unit and widget tests.

Returns exit code `0` if all checks pass; non-zero if formatting, lint, or tests fail.

---

### `build-web.sh`

**Path:** `scripts/build-web.sh`  
**Description:** Compiles the Flutter web application using the CanvasKit renderer and packages production bundles for Vercel deployment.

```bash
# Standard build
./scripts/build-web.sh

# Clean build (cleans build cache before compiling)
./scripts/build-web.sh --clean
```

**Options:**
- `-h`, `--help`: Display usage and options.
- `-c`, `--clean`: Remove stale compilation artifacts before rebuilding.

**Actions performed:**
- Compiles web release bundle targeting `lib/main_production.dart`.
- Packages output to both `deploy/focus/` (subpath base href) and `deploy/` (root fallback).
- Configures custom PWA service worker with the version string from `pubspec.yaml`.
- Copies `web/android/version.json` into `deploy/android/version.json` for OTA checks.

---

### `build_android_apk.sh`

**Path:** `scripts/build_android_apk.sh`  
**Description:** Compiles an unsigned debug APK for local device testing without requiring release keystore credentials.

```bash
./scripts/build_android_apk.sh
```

**Output:** `build/app/outputs/flutter-apk/app-production-debug.apk`

---

### `build_android_release_apk.sh`

**Path:** `scripts/build_android_release_apk.sh`  
**Description:** Compiles a signed release APK ready for production distribution.

```bash
./scripts/build_android_release_apk.sh
```

**Requirements:** Requires `android/key.properties` with valid keystore paths and passwords.  
**Output:** `build/app/outputs/flutter-apk/app-production-release.apk`

---

### `deploy_android_update.sh`

**Path:** `scripts/deploy_android_update.sh`  
**Description:** Automated release pipeline coordinating the full APK build, GitHub Release creation, and in-app OTA manifest update.

```bash
./scripts/deploy_android_update.sh "Short release notes describing the changes"
```

**Actions performed:**
1. Validates that GitHub CLI (`gh`) and `jq` are installed.
2. Extracts version name and version code from `pubspec.yaml`.
3. Calls `scripts/build_android_release_apk.sh`.
4. Copies APK to `build/pomo-production.apk`.
5. Updates `web/android/version.json` with the new version code, download URL, and changelog.
6. Creates or updates GitHub release tag (`v<version>`) and uploads `pomo-production.apk`.
7. Prompts to run `vercel deploy --prod` to publish the updated OTA manifest.

---

### `setup-macos-signing.sh`

**Path:** `scripts/setup-macos-signing.sh`  
**Description:** Configures a local development code-signing identity on macOS so notification banners are accepted by macOS Notification Center.

```bash
./scripts/setup-macos-signing.sh
```

**Why needed:** macOS strictly suppresses notification banners for unsigned or ad-hoc binaries. Running this script signs the Runner bundle with a local self-signed certificate.

---

### `generate-sounds.py`

**Path:** `scripts/generate-sounds.py`  
**Description:** Python utility that synthesizes clean mathematical sine wave audio tones (44100Hz 16-bit PCM WAV) for timer chimes and alerts.

```bash
python3 scripts/generate-sounds.py
```

**Output files in `assets/sounds/`:**
- `chime.wav`: Harmonious double-sine tone for lap starts.
- `bell.wav`: Resonant ringing tone for lap completion.
- `digital_beep.wav`: Distinctive electronic pulse for hourly check-in reminders.

---

### `build_macos_dmg.sh`

**Path:** `build_macos_dmg.sh`  
**Description:** Packages the production macOS application into an Apple Disk Image (`.dmg`) for distribution.

```bash
./build_macos_dmg.sh
```

**Actions performed:**
1. Compiles release bundle: `flutter build macos --release --flavor production -t lib/main_production.dart`.
2. Assembles DMG layout with an `Applications` symlink for drag-and-drop installation.
3. Produces output file `./Pomo.dmg`.
