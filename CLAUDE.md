# CLAUDE.md - Pomo Agent & Developer Guidance

Agent operating rules and workflow entry: see `AGENTS.md`. This file is the detailed topology and build guide for `pomo` (`github.com/rawshn97/pomo`, forked from `recoskyler/pomo`), a cross-platform Pomodoro timer app written in Flutter with WebHook automation and multi-window desktop support.

## 1. Project Topology & Key Directories

- `lib/main.dart`: Stub entry point (`123` bytes). Do **not** run `flutter run` directly without a target and flavor flag.
- `lib/main_development.dart`, `main_staging.dart`, `main_production.dart`: The true entry points for the three build flavors (`development`, `staging`, `production`).
- `lib/app/`: Core `App` and `AppView` widget tree and global `MultiBlocProvider` setup (`SettingsCubit`, `TimerCubit`).
- `lib/desktop/`: Multi-window desktop shell, floating overlay window (`OverlayApp`), and `MacOSMenuBarService`.
- `lib/helpers/`: Pure logic mixins and utility classes (`DurationHelper`, `LapHelper`, `SoundHelper`, `HookHelper`, `LapColorHelper`).
- `lib/l10n/`: Localization files (`arb/app_en.arb`) and generated accessors (`flutter gen-l10n`).
- `lib/pages/`: BLoC/Cubit feature modules (`timer`, `settings`, `about`).
- `lib/services/`: Background execution and platform services (`TimerTickService`).
- `lib/singletons/`: Shared preferences (`Prefs`) and global singletons.
- `scripts/`: Build and utility scripts (`build-web.sh`, `generate-sounds.py`, `setup.sh`, `verify.sh`).
- `assets/`: Sound effects (`click.aac`, `pop.aac`, `ding_dong.aac`, `chime.wav`, `bell.wav`) and SVG/PNG icons.

## 2. Token-Optimized Command Guidelines (`rtk`)

When interacting with the repository via shell commands, always prefix standard tools with `rtk` to reduce context usage:
```bash
# Repository status and search
rtk git status
rtk git diff
rtk grep "TimerStatus"
rtk ls lib/helpers

# Running verification and tests
rtk test flutter test --flavor development
```

## 3. Mandatory Setup & Code Generation

Before running or building the application, ensure code generators have produced necessary localization strings and assets:

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Generate localization strings (REQUIRED - produces AppLocalizations)
flutter gen-l10n

# 3. Generate native splash screens and launcher icons (when editing assets)
dart run flutter_native_splash:create
dart run flutter_launcher_icons
```

Or run the automated setup script:
```bash
./scripts/setup.sh
```

## 4. Running & Building the Application

### Local Development (Preferred Flavor: `development`)
```bash
# macOS desktop run
flutter run --flavor development -d macos --target lib/main_development.dart

# Chrome / Web run
flutter run --flavor development -d chrome --target lib/main_development.dart
```

### Production Builds
```bash
# Web PWA Release Build (produces deploy/focus output)
./scripts/build-web.sh

# macOS Desktop Release Build (.app)
flutter build macos --release --flavor production -t lib/main_production.dart
open build/macos/Build/Products/Release-production/Pomo.app

# macOS DMG (unsigned / ad-hoc)
./build_macos_dmg.sh
open ./Pomo.dmg
```

## 5. Verification & Testing

Always verify that your code changes compile, conform to static analysis (`very_good_analysis`), and pass regression tests:

```bash
# Run unified verification suite
./scripts/verify.sh

# Or run individual steps manually:
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test --flavor development
```

## 6. Architecture & State Management Rules

- **State Management**: Uses `flutter_bloc` (`^8.1.6`). Use `Cubit<State>` for feature modules (`TimerCubit`, `SettingsCubit`). Always emit immutable states (`Equatable`).
- **Singletons**: Global preferences are managed via `Prefs()` (`lib/singletons/prefs.dart`). Always initialize `await Prefs().init()` during bootstrap.
- **Pure Mixins**: Timer logic and lap calculation must stay isolated inside `lib/helpers/` (`DurationHelper`, `LapHelper`) to keep them 100% unit-testable without Flutter widget contexts.
- **Audio & Sound**: Sound playback is routed through `SoundHelper` using `audioplayers` (`^6.0.0`). When adding custom tones, run `scripts/generate-sounds.py`.
- **WebHooks**: Webhook execution happens via `HookHelper` (`lib/helpers/hook_helper.dart`). Always respect `SettingsState.enableWebHooks` before making HTTP calls (`dio`).
- **Desktop notifications**: macOS uses `LocalNotificationService` (`flutter_local_notifications`). Gate with `Prefs.enableDesktopNotifications` and quiet hours via `NotificationHelper`. Hourly reminders live in `HookHelper`; lap events route through `TimerPage._notify`.
- **Launch at login**: `LaunchAtLoginService` + Settings toggle. Login launches start hidden (`.accessory`); opening the window switches to `.regular`.

## 7. No Em Dash Policy

Do **not** use the em dash character (`\u2014`) anywhere in comments, documentation, commit messages, or user-facing strings. Use standard hyphens (`-`), colons (`:`), or semicolons instead.

## 8. Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Shipped behavior / "what is built" -> `SPEC.md` + `specs/`; unshipped -> `SPEC_IN_PROGRESS.md`
- Product ideas/brainstorming -> invoke /office-hours
- Strategy/scope -> invoke /plan-ceo-review
- Architecture -> invoke /plan-eng-review
- Design system/plan review -> invoke /design-consultation or /plan-design-review
- Full review pipeline -> invoke /autoplan
- Bugs/errors -> invoke /investigate
- QA/testing site behavior -> invoke /qa or /qa-only
- Code review/diff check -> invoke /review
- Visual polish -> invoke /design-review
- Ship/deploy/PR -> invoke /ship or /land-and-deploy
- Save progress -> invoke /context-save
- Resume context -> invoke /context-restore
- Author a backlog-ready spec/issue -> invoke /spec
