# Ops: setup, verify, builds

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `scripts/`, flavors

---

## Setup

```bash
./scripts/setup.sh
# or: flutter pub get && flutter gen-l10n
```

Splash / icons (when assets change):

```bash
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

## Verify (required after product changes)

```bash
./scripts/verify.sh
# optional: ./scripts/verify.sh --test cubit
```

Runs pub get, gen-l10n, `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test --flavor development`.

Inspect with `rtk` where applicable (`rtk git status`, `rtk grep`).

## Run

```bash
flutter run --flavor development -d macos --target lib/main_development.dart
flutter run --flavor development -d chrome --target lib/main_development.dart
```

## Production artifacts

| Artifact | Command |
|----------|---------|
| Web PWA | `./scripts/build-web.sh` |
| macOS `.app` | `flutter build macos --release --flavor production -t lib/main_production.dart` |
| macOS DMG | `./build_macos_dmg.sh` |
| Android APK | `scripts/build_android_apk.sh` / `build_android_release_apk.sh` (production flavor) |
| Android OTA | `scripts/deploy_android_update.sh` + Vercel `version.json` |

macOS notification banners need `./scripts/setup-macos-signing.sh` (not ad-hoc).

## Agent docs vs this spec

| File | Role |
|------|------|
| `AGENTS.md` | Short operating rules |
| `DEPLOYMENT.md` | Deployment, packaging, and release guide for agents |
| `CLAUDE.md` | Topology and command copy-paste |
| `SPEC.md` + `specs/` | Shipped product contracts |
| `docs/superpowers/` | Process rails, gap matrix, dated plans, QA reports |

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial shipped ops spec |
