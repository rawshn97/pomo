# How-To: Release and Deploy

This guide covers the end-to-end release process for Pomo across all distribution targets: Android APK with in-app OTA updates, macOS desktop DMG, and the Web PWA on Vercel.

---

## 1. Single Branch Release Architecture

Pomo uses a single-branch release workflow:

- All production releases build directly from `main`.
- Open source code and personal production deployments share the exact same codebase without diverging branches.
- Platform specific behaviors adapt dynamically via environment variables, runtime origin inspection (`Uri.base.origin`), and build flavors.

---

## 2. Pre-Release Verification (Mandatory)

Always execute the complete verification suite before building any release artifacts:

```bash
./scripts/verify.sh
```

Ensure that formatting, static analysis (`very_good_analysis`), and the full test suite pass with zero errors.

### Version Bumping Protocol

1. Open `pubspec.yaml` and increment the version and build number:
   ```yaml
   version: 1.4.8+19
   ```
2. If any user-facing strings or localizations changed, regenerate localization code:
   ```bash
   flutter gen-l10n --arb-dir="lib/l10n/arb"
   ```
3. Update `CHANGELOG.md` with notes describing the changes, bug fixes, or new features.

---

## 3. Web PWA Deployment (Vercel)

The Web PWA is deployed to Vercel and serves the full CanvasKit application.

### Prerequisites

- Global Vercel CLI installed (`npm install -g vercel`).
- Never use `npx vercel` to avoid repeated permission prompts on macOS.

### Deployment Steps

1. From the repository root, deploy to production:
   ```bash
   vercel deploy --prod
   ```
2. Vercel automatically runs `scripts/build-web.sh`, which:
   - Fetches dependencies and compiles Flutter Web with CanvasKit.
   - Sets the base href to `/focus/` and copies root fallbacks to `deploy/`.
   - Patches the service worker for reliable PWA caching.
   - Bundles the Android OTA update manifest (`deploy/android/version.json`).
3. Verify required environment variables in the Vercel dashboard:
   - `NOTION_TOKEN`: Internal Notion integration token for the `/api/notion/` proxy.
   - `FOCUS_ACCESS_TOKEN`: Private user access passphrase.

### Subpath Reverse Proxy (e.g. `rawshn.com/focus`)

To host the PWA on an existing website under a subpath like `/focus/`, add rewrites in your host project (e.g. `vercel.json` or `next.config.js`):

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
]
```

---

## 4. Android Release Build and In-App OTA

Pomo Android production builds (`com.recoskyler.pomo`) feature integrated Over-The-Air (OTA) updates. Users do not need an app store or manual ADB side-loading for updates.

### Prerequisites: Signing Keystore

Production builds require a release keystore configured in `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=pomo
storeFile=/Users/username/Keys/pomo-release.jks
```

> [!WARNING]
> Always use the same release keystore (`pomo-release.jks`) across releases. Android will refuse to install or update an APK signed with a different key.

### Automated Release Pipeline (Recommended)

Run the all-in-one release script with your release notes:

```bash
./scripts/deploy_android_update.sh "Added real-time WebSocket sync and smooth shade countdown"
```

This automated script performs the following actions:
1. Reads the current version and build number from `pubspec.yaml`.
2. Builds the signed release APK using `scripts/build_android_release_apk.sh`.
3. Updates the OTA manifest at `web/android/version.json` with the new version code, version name, APK download URL, and release notes.
4. Uses `gh release create` to create a GitHub Release tag (`v<version>`) and uploads `pomo-production.apk`.
5. Deploys the updated `version.json` manifest to Vercel via `vercel deploy --prod`.

Once deployed, all installed Android devices will show an update prompt on next launch or when the user taps **Check for updates** in Settings.

### Local APK Build Only

To compile a signed production APK locally without creating a GitHub release:

```bash
./scripts/build_android_release_apk.sh
```

Output: `build/app/outputs/flutter-apk/app-production-release.apk`

To build an unsigned debug APK for local device testing:

```bash
./scripts/build_android_apk.sh
```

---

## 5. macOS Desktop Release and DMG

macOS builds bundle menu bar controls, floating overlay windows, and native desktop notifications.

### Prerequisites: macOS Signing Identity

Run the signing helper script once:

```bash
./scripts/setup-macos-signing.sh
```

### Build the Application Bundle

Compile the production macOS app bundle:

```bash
flutter build macos --release --flavor production -t lib/main_production.dart
```

Output location: `build/macos/Build/Products/Release-production/Pomo.app`

### Package the DMG

Create a distributable DMG image:

```bash
./build_macos_dmg.sh
```

Output: `./Pomo.dmg`

### Upload to GitHub Releases

Upload the DMG to the corresponding GitHub Release tag:

```bash
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1)
gh release upload "v${VERSION}" "./Pomo.dmg" --clobber
```

---

## 6. Release Checklist

| Step | Action | Command |
|---|---|---|
| 1 | Run full verification | `./scripts/verify.sh` |
| 2 | Bump version | Edit `pubspec.yaml` + `CHANGELOG.md` |
| 3 | Update translations | `flutter gen-l10n --arb-dir="lib/l10n/arb"` |
| 4 | Deploy Android OTA | `./scripts/deploy_android_update.sh "<notes>"` |
| 5 | Build macOS DMG | `./build_macos_dmg.sh` && `gh release upload v<version> Pomo.dmg` |
| 6 | Deploy Web PWA | `vercel deploy --prod` |
| 7 | Commit & Push | `git commit -am "chore(release): v<version>"` && `git push origin main` |
