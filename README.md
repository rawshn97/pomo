# Pomo

Cross-platform Pomodoro timer with 24-hour hourly time tracking, Notion PARA sync, and RGB webhooks.

**Live Web App (PWA):** [pomo-focus-sand.vercel.app](https://pomo-focus-sand.vercel.app)  
**Latest Release:** [GitHub Releases (v1.3.9)](https://github.com/rawshn97/pomo/releases/tag/v1.3.9) (Android APK with in-app OTA, macOS DMG)  
**Docs:** [SPEC.md](SPEC.md) (shipped behavior) · [AGENTS.md](AGENTS.md) (contributor & agent rules) · [ARCHITECTURE.md](ARCHITECTURE.md) (system design)

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

| Focus Timer | 24h Hourly Tracker | Settings & Integrations |
|:---:|:---:|:---:|
| ![Focus Timer](assets/images/hero-timer.png) | ![Hourly Tracker](assets/images/hero-tracker.png) | ![Settings & Integrations](assets/images/hero-settings.png) |

---

## Upstream vs This Fork

| Upstream (`recoskyler/pomo`) | This repo (`rawshn97/pomo`) |
|---|---|
| Single timer screen, webhooks, themes | 3-tab `HomeShell`: Focus, Hourly Tracker, Settings |
| No hourly grid | 24h grid, missed hours, custom tags, quiet hours / Resting |
| No Notion | PARA Time Logs + Hourly Timeline + tag registry |
| No Android background story | FGS timer tile, exact hourly alarms, 1-tap Log Work |
| Manual APK | Production APK + in-app OTA + GitHub Releases + macOS DMG |
| Web build to `docs/` | Vercel PWA (`pomo-focus-sand.vercel.app`) + Notion proxy |

---

## Features

### Focus timer

- Adjustable work, short break, and long break durations
- Lap count, auto-advance, custom sounds and timer fonts
- Light / dark theme and color seeds
- Optional Notion task picker: log Pomodoro sessions to your PARA Time Logs database
- Credit work minutes to hourly activity tags when the time tracker is on

### Hourly time tracker

- 24-hour grid and analytics (missed hours, multi-tag splits)
- Custom activity tags (emoji + color) synced with Notion
- Quiet hours: suppress reminders; empty slots can fill as Sleep & Rest
- Android: exact hourly alarms, shade notifications (Log Work / Switch Tag / Open Grid)

### Integrations

- **Webhooks:** POST RGB JSON on timer events (comma-separated URLs). Built for [Home Assistant](https://www.home-assistant.io/docs/automation/trigger/#webhook-trigger) ambient lighting.
- **Notion:** Time Logs, Hourly Timeline, activity tag registry (optional proxy on web; see [specs/web.md](specs/web.md)).

### Platforms

| Platform | Install | Notes |
|----------|---------|--------|
| **Android** | [Releases (v1.3.9)](https://github.com/rawshn97/pomo/releases/tag/v1.3.9) → `pomo-production.apk` | Production package `com.recoskyler.pomo`. In-app OTA after first install (see below). |
| **macOS** | [Releases](https://github.com/rawshn97/pomo/releases) or [build locally](#macos) | Menu bar, floating overlay, desktop notifications, launch at login |
| **Web (PWA)** | [Live App](https://pomo-focus-sand.vercel.app) or deploy via `./scripts/build-web.sh` | CanvasKit PWA; pair with Vercel proxy for Notion on browser |

---

## Installing

### Android (recommended: GitHub Releases)

1. Open **[github.com/rawshn97/pomo/releases](https://github.com/rawshn97/pomo/releases)** on your phone (or download on desktop and transfer).
2. Download **`pomo-production.apk`** from the latest release.
3. Install the APK. If prompted, allow **Install unknown apps** for your browser or file manager.
4. On first launch after install, allow **Install unknown apps** for **Pomo** as well (needed for in-app updates).

**Updates:** Production builds check for updates on launch and in **Settings → Check for updates**. New versions download from GitHub Releases automatically once the OTA manifest is published (no USB / ADB). Details: [specs/android.md](specs/android.md).

### macOS

Download a release build from [Releases](https://github.com/rawshn97/pomo/releases), or build locally (see [macOS](#macos)). Run `./scripts/setup-macos-signing.sh` once so notification banners work (ad-hoc signed apps are refused by macOS).

---

## Keyboard shortcuts (desktop / web)

| Key | Action |
|-----|--------|
| <kbd>Space</kbd> or <kbd>Enter</kbd> | Start / pause |
| <kbd>s</kbd> | Skip lap |
| <kbd>r</kbd> or <kbd>Backspace</kbd> | Reset |

---

## Webhooks and Home Assistant

Configure URLs under **Settings → Webhooks**. Each trigger sends JSON like:

```json
{
  "rgb": [255, 0, 156]
}
```

(`rgb` matches the timer ring color.) Multiple URLs: comma-separated.

Example Home Assistant automation (timer tick):

```yaml
alias: Timer Tick Webhook
description: "Runs every second, whenever Pomo ticks."
trigger:
  - platform: webhook
    allowed_methods:
      - POST
      - PUT
    local_only: true
    webhook_id: "-YOUR_WEBHOOK_ID"
condition:
  - condition: device
    type: is_on
    device_id: REPLACE_WITH_DEVICE_ID
    entity_id: REPLACE_WITH_ENTITY_ID
    domain: light
action:
  - service: light.turn_on
    data:
      rgb_color: "{{ trigger.json['rgb'] }}"
      transition: 1
    target:
      entity_id: light.YOUR_LIGHT
mode: single
```

---

## macOS desktop

Native macOS features (not in the browser PWA):

- Menu bar controls (start / pause, reset, settings, quit)
- Background mode: close window → stays in menu bar
- Floating timer pill over fullscreen apps
- Desktop notifications (hourly check-ins, lap end)
- Launch at login (starts hidden in menu bar)

Hourly logs and custom activity tags sync across clients via the Notion Hourly Timeline database.

### macOS

```sh
# One-time signing (required for notification banners)
./scripts/setup-macos-signing.sh

# Run (production)
flutter run --flavor production -d macos --target lib/main_production.dart

# Release .app
flutter build macos --release --flavor production -t lib/main_production.dart
open build/macos/Build/Products/Release-production/Pomo.app

# DMG (personal / unsigned)
./build_macos_dmg.sh
open ./Pomo.dmg
```

---

## Development

### Prerequisites

```sh
./scripts/setup.sh
# or: flutter pub get && flutter gen-l10n
```

### Flavors

| Flavor | Entry point | Use |
|--------|-------------|-----|
| `production` | `lib/main_production.dart` | Release APK, macOS, web PWA, personal installs |
| `staging` | `lib/main_staging.dart` | Pre-release QA |
| `development` | `lib/main_development.dart` | Local dev (overlay window, extra tooling) |

`lib/main.dart` is a stub. Always pass `--flavor` and `--target`.

```sh
flutter run --flavor development -d macos --target lib/main_development.dart
flutter run --flavor production -d chrome --target lib/main_production.dart
```

### Verify

```sh
./scripts/verify.sh
```

Runs format check, `flutter analyze`, and tests.

---

## Building release artifacts

| Artifact | Command |
|----------|---------|
| Android APK (production) | `./scripts/build_android_release_apk.sh` |
| Android OTA ship | `./scripts/deploy_android_update.sh "changelog"` then `vercel deploy --prod` |
| Web PWA | `./scripts/build-web.sh` |
| macOS `.app` | `flutter build macos --release --flavor production -t lib/main_production.dart` |
| macOS DMG | `./build_macos_dmg.sh` |

**Android signing:** Copy `android/key.properties.example` -> `android/key.properties` and point at your release `.jks`. Use the **same keystore** for every release or Android will treat updates as a different app. (Maintainers and agents: see [AGENTS.md](AGENTS.md) for signing keystore recovery instructions).

---

## Translations

Strings live in `lib/l10n/arb/app_en.arb`. After editing:

```sh
flutter gen-l10n --arb-dir="lib/l10n/arb"
```

Asset codegen (when icons / splash change):

```sh
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

---

## Docs map

| File | Purpose |
|------|---------|
| [README.md](README.md) | Install and build (this file) |
| [SPEC.md](SPEC.md) | Shipped product index |
| [specs/](specs/) | Per-feature contracts |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design |
| [AGENTS.md](AGENTS.md) | Agent operating rules |
| [CLAUDE.md](CLAUDE.md) | Topology and commands |

---

## About

By [rawshn97](https://github.com/rawshn97). Fork lineage: [recoskyler/pomo](https://github.com/recoskyler/pomo).

Timer font **Major Mono Display** by Emre Parlak.

[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
