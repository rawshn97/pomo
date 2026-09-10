# macOS desktop shell

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `lib/desktop/`, `macos/`

---

## Purpose

Native macOS extras beyond the shared Flutter tabs. Not available in the browser PWA.

## Main window

`DesktopWindowService` + `window_manager`: restore size (min 500×500), always-on-top, title `Pomo`. Login launches can start **hidden** (`.accessory`); opening the window switches to `.regular`.

## Menu bar

`MacOSMenuBarService` + `macos/Runner/MenuBarPlugin.swift` (`NSStatusItem`): start/pause, reset, settings, show window, quit. App can keep running after the main window is closed.

## Floating overlay

`OverlayApp` in a `desktop_multi_window` process (`args` `multi_window`). Always-on-top countdown pill. IPC only: `FloatingOverlayController` pushes `updateTimer` from `TimerCubit` on every tick; overlay sends `overlayReady` on startup so the main window can sync immediately. Do not poll `Prefs` from the overlay engine (SharedPreferences is cached per Flutter engine). Display only (no tag/task pickers).

## Notifications

`LocalNotificationService` (`flutter_local_notifications`). Hourly check-ins and lap-complete copy from `NotificationHelper`. Requires a **real signing identity** for banners (`./scripts/setup-macos-signing.sh`); ad-hoc signed builds are refused by `UNUserNotificationCenter`.

Taps route through `AppNavigationController`.

## Launch at login

`LaunchAtLoginService` → `SMAppService.mainApp` (macOS 13+) via MethodChannel in `MainFlutterWindow.swift`.

## Packaging

```bash
flutter build macos --release --flavor production -t lib/main_production.dart
./build_macos_dmg.sh
```

Unsigned / ad-hoc DMG is for personal use.

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial shipped desktop spec |
