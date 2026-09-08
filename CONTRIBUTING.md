# CONTRIBUTING.md - Developer Onboarding & Contribution Guide

Welcome to the `pomo` repository (`github.com/rawshn97/pomo`)! We appreciate your interest in contributing to our open-source Pomodoro timer. This guide will walk you through setting up your local environment, working with localization strings, verifying your code changes, and submitting pull requests.

---

## 1. Prerequisites & System Requirements

Before contributing code, verify that your local development environment meets the following requirements:

- **Flutter SDK**: `^3.6.0` (Recommended: Flutter `3.27.1` or newer)
- **Dart SDK**: `^3.5.4` or newer
- **Platform Toolchains**:
  - For macOS / iOS builds: Xcode (`15.0+`) and CocoaPods installed.
  - For Linux builds: `apt-get install libgstreamer1.0-dev libgtk-3-dev liblzma-dev clang cmake ninja-build pkg-config`
  - For Web builds: Chrome browser installed.

---

## 2. Quick Setup & First Build (Time to Hello World < 3 min)

To get up and running immediately after cloning the repository, execute our automated setup script (`rtk`-optimized):

```bash
# 1. Clone repository
rtk git clone https://github.com/rawshn97/pomo.git
cd pomo

# 2. Run automated onboarding setup script (fetches dependencies & runs generators)
./scripts/setup.sh

# 3. Launch local development build (example: macOS desktop)
flutter run --flavor development -d macos --target lib/main_development.dart
```

> [!IMPORTANT]
> Never run `flutter run` without `--flavor` and `--target`. The root `lib/main.dart` is a stub file (`123` bytes) and will not initialize target-specific dependencies correctly.

---

## 3. Localization & Translation Workflow (`l10n`)

`pomo` supports internationalization via `flutter_localizations` (`lib/l10n/arb/`). When adding new text or modifying UI strings, follow this strict procedure:

### A. Adding a New String
Open `lib/l10n/arb/app_en.arb` and add your key with a descriptive `@key` block:
```arb
{
  "@@locale": "en",
  "myNewFeatureTitle": "New Feature",
  "@myNewFeatureTitle": {
    "description": "Title displayed on the top app bar of the new feature page"
  }
}
```

### B. Regenerating Localization Classes
Whenever you modify `.arb` files, regenerate the Dart localization accessors:
```bash
flutter gen-l10n --arb-dir="lib/l10n/arb"
```
Or run `./scripts/setup.sh`.

### C. Using Strings in UI Code
In any `Widget` `build` method, access your newly generated string via context extension:
```dart
import 'package:pomo/l10n/l10n.dart';

@override
Widget build(BuildContext context) {
  final l10n = context.l10n;
  return Text(l10n.myNewFeatureTitle);
}
```

---

## 4. Code Generation for Assets & Icons

If your pull request modifies audio files (`assets/sounds/`), logos (`assets/images/`), or fonts (`fonts/`), run the corresponding asset generators:

```bash
# Generate splash screen overlays
dart run flutter_native_splash:create

# Generate application launcher icons across Android/iOS/macOS
dart run flutter_launcher_icons

# Generate synthesized WAV alert sounds (if modifying scripts/generate-sounds.py)
python3 scripts/generate-sounds.py
```

---

## 5. Coding Standards & Lints (`very_good_analysis`)

Our codebase enforces strict Dart linting rules via `very_good_analysis` (`^7.0.0`). To ensure your pull request passes continuous integration:

1. **Do Not Suppress Lints**: Avoid `// ignore: ...` comments unless working around an explicit compiler limitation.
2. **Immutable State Transitions**: In BLoC/Cubit files (`lib/pages/*/cubit/`), all state classes must extend `Equatable` and use clean `copyWith(...)` methods.
3. **Pure Logic Mixins**: Place non-UI logic (calculations, time math, lap sequencing) into pure helper mixins (`lib/helpers/`) to allow fast unit testing without widget inflation.
4. **No Em Dashes**: Never use the em dash character (`\u2014`) anywhere in code strings, documentation, or commit messages. Use hyphens (`-`), colons (`:`), or semicolons.

---

## 6. Pre-Commit Verification Checklist

Before submitting a pull request, run the unified verification script to ensure zero regressions:

```bash
./scripts/verify.sh
```

This script will verify:
- Clean static analysis (`flutter analyze --no-fatal-infos`)
- Standard Dart formatting (`dart format --output=none --set-exit-if-changed .`)
- Up-to-date localizations (`flutter gen-l10n`)
- 100% passing regression test suite (`flutter test --flavor development`)

---

## 7. Pull Request Process

1. Fork the repository and create a descriptive feature branch (`git checkout -b feat/add-dark-theme-toggle`).
2. Make your atomic changes and write corresponding automated tests in `test/`.
3. Verify changes locally using `./scripts/verify.sh`.
4. Open a pull request against `main` using our pull request template (`.github/PULL_REQUEST_TEMPLATE.md`).
5. Ensure GitHub Actions CI checks (`.github/workflows/ci.yaml`) complete successfully.
