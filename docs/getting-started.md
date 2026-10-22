# Getting Started with Pomo

This step-by-step tutorial guides you from a fresh git clone to running Pomo locally on macOS, Android (emulator or physical phone), and the Web PWA.

---

## 1. Prerequisites

Before starting, ensure your system has the following installed:

- **Git**: 2.30+
- **Flutter SDK**: 3.19.0+ (stable channel)
  - Verify with: `flutter --version`
  - Run `flutter doctor` to confirm toolchain health.
- **Java Development Kit (JDK)**: Java 17 (Zulu JDK 17 recommended for Android builds)
  - Verify with: `java -version`
- **Platform-specific requirements**:
  - **macOS Desktop**: Xcode 15+ with command line tools (`xcode-select --install`).
  - **Android**: Android Studio with Android SDK Platform 34+, Android SDK Build-Tools, and an Android 13+ emulator or physical phone with USB debugging enabled.
  - **Web**: Google Chrome or any modern Chromium-based browser.

---

## 2. Clone and Bootstrap

Clone the repository and enter the project directory:

```bash
git clone https://github.com/rawshn97/pomo.git
cd pomo
```

Run the automated setup script to download packages and generate localization files:

```bash
./scripts/setup.sh
```

Alternatively, run the Flutter commands directly:

```bash
flutter pub get
flutter gen-l10n --arb-dir="lib/l10n/arb"
```

---

## 3. Understand Flavors and Entry Points

Pomo uses three distinct build flavors:

| Flavor | Target Entry Point | Typical Use Case |
|---|---|---|
| `development` | `lib/main_development.dart` | Local development, verbose logging, multi-window overlay debugging |
| `staging` | `lib/main_staging.dart` | Pre-release QA and integration testing |
| `production` | `lib/main_production.dart` | Release builds (APKs, macOS app bundles, Vercel web PWA) |

> [!IMPORTANT]
> `lib/main.dart` is an empty stub. Never execute `flutter run` without the `--flavor` and `--target` arguments. Always specify both flags.

---

## 4. Run on macOS Desktop

Running on macOS gives you the full desktop experience: the 3-tab `HomeShell`, native menu bar controls, floating overlay window, and desktop notification banners.

### Step 4a: One-time macOS notification signing

macOS blocks notification banners for ad-hoc unsigned applications. Run the helper script once to configure a local development signing identity:

```bash
./scripts/setup-macos-signing.sh
```

### Step 4b: Launch the development app

Start Pomo targeted to your Mac:

```bash
flutter run --flavor development -d macos --target lib/main_development.dart
```

### Step 4c: Verify macOS features

1. **Focus Timer**: Press <kbd>Space</kbd> or <kbd>Enter</kbd> to start the countdown. Press <kbd>s</kbd> to skip lap, or <kbd>r</kbd> to reset.
2. **Menu Bar Item**: Look at your macOS menu bar for the timer icon. Click it to see quick actions (Start/Pause, Reset, Settings, Quit).
3. **Floating Overlay**: In development mode, the floating overlay window can be launched over fullscreen workspaces.

---

## 5. Run on Android (Emulator or Device)

Android provides background tick handling via a Foreground Service (FGS), exact hourly `AlarmManager` reminders, and notification shade actions.

### Step 5a: Connect emulator or device

Ensure an emulator is booted or your physical device is connected:

```bash
flutter devices
```

Verify that your Android device appears in the output list.

### Step 5b: Launch on Android

Start the application on your Android target:

```bash
flutter run --flavor development -d android --target lib/main_development.dart
```

(Replace `android` with your device ID if multiple devices are attached).

### Step 5c: Grant system permissions

On first launch on Android:

1. **Notifications**: When prompted, grant notification permissions so the timer tile and hourly check-in notifications can appear in your shade.
2. **Exact Alarms**: Android 13+ requires permission to schedule exact hourly alarms. When prompted on the Hourly Tracker tab, allow alarms.
3. **Battery Optimization**: Open **Settings -> Android Background Service** and request battery optimization exemption to prevent the OS from killing background ticks.

### Step 5d: Test background notification shade

1. Start a focus sprint on the **Timer** tab.
2. Swipe the app to the background or lock your phone.
3. Pull down your notification shade: observe the active timer notification tile updating in real time with Play/Pause and Reset buttons.

---

## 6. Run on Web (PWA)

The Web target compiles the application using Flutter CanvasKit for smooth 60fps animations in modern desktop and mobile browsers.

### Step 6a: Launch in Chrome

Run the web flavor in Google Chrome:

```bash
flutter run --flavor development -d chrome --target lib/main_development.dart
```

### Step 6b: Explore the Web PWA

1. Open `http://localhost:<port>` in Chrome.
2. The 3-tab navigation adapts to screen width: a left `NavigationRail` appears on wide monitors, while a bottom `NavigationBar` renders on narrow viewports.
3. Use the keyboard shortcuts (<kbd>Space</kbd>, <kbd>Enter</kbd>, <kbd>s</kbd>, <kbd>r</kbd>) to drive the focus sprint.

> [!NOTE]
> Web browsers enforce CORS when talking to third-party APIs like `api.notion.com`. To test Notion synchronization in the browser, see [How-To: Set Up Notion Sync](how-to/setup-notion-sync.md) for configuring the reverse proxy.

---

## 7. Run Verification and Quality Checks

Before committing any changes or opening a pull request, run the complete verification script:

```bash
./scripts/verify.sh
```

This script enforces:
1. **Formatting**: `dart format --output=none --set-exit-if-changed` across `lib/`, `test/`, and `scripts/`.
2. **Static Analysis**: `flutter analyze` against the strict `very_good_analysis` linter ruleset.
3. **Automated Tests**: `flutter test --flavor development` executing unit, widget, and state cubit tests.

---

## 8. Where to Go Next

Now that your local environment is up and running, explore:

- [How-To: Set Up Notion Sync](how-to/setup-notion-sync.md): Configure two-way sync with your Notion PARA workspace.
- [How-To: Set Up Cloudflare Worker](how-to/setup-cloudflare-worker.md): Deploy your own real-time WebSocket sync relay.
- [How-To: Release and Deploy](how-to/release-and-deploy.md): Package signed Android APKs, macOS DMGs, and Vercel web builds.
- [Explanation: Target Timestamp Sync Model](explanation/target-timestamp-sync-model.md): Deep-dive into cross-device timer synchronization.
- [Reference: Scripts](reference/scripts.md): Quick reference for all repository tooling scripts.
- [Reference: Environment Variables](reference/environment-variables.md): Overview of all environment variables and build flags.
