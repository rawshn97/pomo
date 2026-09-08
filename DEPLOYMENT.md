# DEPLOYMENT.md - Pomo Deployment Guide

This document is the operational deployment guide for AI agents and maintainers of `pomo` (`github.com/rawshn97/pomo`). It details how to build, verify, package, and deploy all supported targets (Web PWA, Android APK / OTA, macOS DMG) from the `main` branch without requiring separate deployment branches.

---

## Architecture Overview

The repository uses a single `main` branch with decoupled configuration:
- **No Deployment Branches:** All public open-source code and personal deployment targets share the exact same codebase on `main`.
- **Dynamic Origin Resolution on Web:** In Web PWA mode (`kIsWeb`), the app dynamically queries its current origin via `Uri.base.origin` and resolves the Notion proxy path relative to that origin (`$origin/api/notion/`). This allows the exact same web bundle to work on `pomo-focus-sand.vercel.app`, `rawshn.com/focus`, or `localhost`.
- **Direct Native API Option:** Native mobile/desktop builds connect directly to `https://api.notion.com/v1/` when a direct Notion integration token (`secret_...` or `ntn_...`) is provided in Settings, without needing any intermediary proxy.
- **Configurable OTA Manifest:** Android update checking reads `AppUpdateConfig.manifestUrl`, which defaults to `https://pomo-focus-sand.vercel.app/android/version.json` and can be overridden at compile time via `--dart-define=UPDATE_MANIFEST_URL=...`.
- **Untracked Release Secrets:** Android release signing keys and Vercel serverless secrets are kept out of Git.

---

## 1. Pre-Deployment Verification (Mandatory)

Always run the full verification suite before any deployment. Never deploy an artifact if verification fails.

```bash
# Run complete verification (formatting, static analysis, unit/widget tests)
./scripts/verify.sh
```

Or run individual verification steps:
```bash
# 1. Formatting check
dart format --output=none --set-exit-if-changed lib/ test/ scripts/

# 2. Static analysis
flutter analyze

# 3. Regression test suite
flutter test --flavor development
```

---

## 2. Web PWA Deployment (Vercel)

The Web PWA is hosted on Vercel under project `pomo-focus`.

### Production Targets
- **Direct Vercel URL:** `https://pomo-focus-sand.vercel.app`
- **Portfolio Subpath:** `https://rawshn.com/focus/`

### Deployment Steps (Direct Vercel Project)
1. Ensure you have the global `vercel` CLI installed (`which vercel`). Never use `npx vercel`.
2. From the `pomo` repository root, deploy directly to production:
   ```bash
   vercel deploy --prod
   ```
3. Vercel automatically runs `scripts/build-web.sh`, compiling Flutter web with CanvasKit and base href `/focus/`, placing outputs in `deploy/` and `deploy/focus/`.
4. Required environment variables in Vercel project settings:
   - `NOTION_TOKEN`: Internal Notion integration token used by `/api/notion` serverless proxy.
   - `FOCUS_ACCESS_TOKEN`: Shared access code entered by users on browser sessions.

### Serving at `rawshn.com/focus`
To serve the PWA under `rawshn.com/focus/`, the host site (`rawshn-portfolio`) proxies requests to `pomo-focus-sand.vercel.app`.
In `rawshn-portfolio` (e.g. `next.config.js` or `vercel.json`):
```json
{
  "rewrites": [
    {
      "source": "/focus/:path*",
      "destination": "https://pomo-focus-sand.vercel.app/focus/:path*"
    },
    {
      "source": "/api/notion/:path*",
      "destination": "https://pomo-focus-sand.vercel.app/api/notion/:path*"
    }
  ]
}
```
Any deployment to `pomo`'s `main` branch is immediately reflected on `rawshn.com/focus` without modifying `rawshn-portfolio`.

---

## 3. Android Release Build & In-App OTA Deployment

Android production updates are distributed through GitHub Releases and in-app OTA check.

### Prerequisites (Release Signing)
1. Android production builds require a stable keystore (`pomo-release.jks`) configured in `android/key.properties`.
2. If `android/key.properties` is missing on the build machine, follow the keystore recovery protocol in `AGENTS.md` (Notion Personal Assets -> Pomo Android Release Keystore).
3. Verify `android/key.properties` contains:
   ```properties
   storePassword=<PASSWORD>
   keyPassword=<PASSWORD>
   keyAlias=pomo
   storeFile=/Users/<username>/Keys/pomo-release.jks
   ```

### Option A: Automated Build + GitHub Release + OTA Bump (Preferred)
Run the all-in-one deploy script:
```bash
./scripts/deploy_android_update.sh "Short release notes describing the update"
```

What this script executes:
1. Reads version and build number from `pubspec.yaml` (e.g. `1.3.9+12` -> tag `v1.3.9`).
2. Compiles signed production APK (`build/app/outputs/flutter-apk/app-production-release.apk`) using `scripts/build_android_release_apk.sh`.
3. Updates `web/android/version.json` with the new `versionCode`, `versionName`, download URL, and changelog.
4. Uses `gh release` to create or update the GitHub Release tag `v<version>` and uploads `pomo-production.apk`.
5. After running, deploy the updated `version.json` manifest to Vercel:
   ```bash
   vercel deploy --prod
   ```
   Installed devices will receive the update prompt on next launch.

### Option B: Local Build Only (No Release Publish)
To build the signed APK locally without publishing a GitHub release:
```bash
./scripts/build_android_release_apk.sh
# Output: build/app/outputs/flutter-apk/app-production-release.apk
```

To build an unsigned debug APK for testing (no keystore needed):
```bash
./scripts/build_android_apk.sh
# Output: build/app/outputs/flutter-apk/app-production-debug.apk
```

---

## 4. macOS Desktop Release Build & DMG

macOS builds provide menu bar mode, floating overlay window, and desktop notification integration.

### Prerequisites (macOS Code Signing)
Run the signing setup script once on the build Mac:
```bash
./scripts/setup-macos-signing.sh
```
This configures local identity signing so notification banners and launch-at-login work properly on macOS.

### Building macOS Artifacts
1. Build the production `.app` bundle:
   ```bash
   flutter build macos --release --flavor production -t lib/main_production.dart
   ```
2. Build the distribution DMG image:
   ```bash
   ./build_macos_dmg.sh
   # Output: ./Pomo.dmg
   ```
3. Upload `Pomo.dmg` to the corresponding GitHub Release tag using `gh`:
   ```bash
   gh release upload "v1.3.9" "./Pomo.dmg" --clobber
   ```

---

## 5. Agent Deployment Checklist

When an agent is asked to deploy an update:

1. **Check Clean Git State:** Run `git status` to ensure all working changes are committed or stashed.
2. **Bump Version (if shipping a new release):**
   - Update `version:` in `pubspec.yaml` (e.g. `1.4.0+13`).
   - If UI strings changed, run `flutter gen-l10n`.
3. **Run Verification:** Run `./scripts/verify.sh` and ensure exit code is 0.
4. **Deploy Web:** Run `vercel deploy --prod`.
5. **Deploy Android (if releasing mobile update):**
   - Run `./scripts/deploy_android_update.sh "<release notes>"`.
   - Run `vercel deploy --prod` to push the new `version.json`.
6. **Deploy macOS (if releasing desktop update):**
   - Run `./build_macos_dmg.sh`.
   - Run `gh release upload "v<version>" "./Pomo.dmg" --clobber`.
7. **Commit & Push:** Commit version bumps and docs to `main`, then `git push origin main`.
