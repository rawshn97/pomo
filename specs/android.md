# Android background and notifications

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `lib/services/android_notification_service.dart`, `android/`

---

## Purpose

Keep the focus timer visible and fire **exact** hourly check-ins on Android 16 (`API 36`) despite Doze. Dart UI is the same `HomeShell`; this spec is native + channel behavior.

MethodChannel: `com.recoskyler.pomo/timer_notification` (`AndroidNotificationService`, `MainActivity.kt`).

## Timer foreground service (FGS)

- `TimerForegroundService`, `SPECIAL_USE` on API 34+.
- Notification ID **1001**, channel `pomo_timer_channel_v2`, ongoing while a session is active.
- Actions: Play / Pause / Stop (wired to `TimerCubit`).
- `START_NOT_STICKY`. Dart restarts FGS on the next `updateTimerState` if a lap is active.
- **D5:** if `startForegroundService` is denied, fall back to `NotificationManager.notify(1001)` with the same actions.

## Hourly shade notification (not FGS)

- ID **1002**, channel `hourly_tracker_v2` (high importance, `digital_beep`).
- Auto-cancel; must not call `startForeground` for 1002 (would steal the timer tile).
- Paths: `HourlyAlarmReceiver` (exact `AlarmManager` + WakeLock) and in-process `HookHelper` → `showHourlyNotification`.

Payload: `hourly:H:YYYY-MM-DD` plus optional `:log_work` / `:switch_tag` / `:open_grid`.

| Action | Behavior |
|--------|----------|
| Log 60m Work | Instant local hourly write (A21) |
| Switch Tag | Opens hourly dialog |
| Open Grid | Switches to tracker tab |

## Exact alarms and battery

- `HourlyAlarmScheduler` + `BootReceiver` reschedule `RTC_WAKEUP`.
- Quiet hours mirrored into native prefs; gated at fire time.
- Settings: `AndroidBatteryOptTile` (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). Tracker soft prompt on enable.

## Residual (not closed by host tests)

Overnight Doze, reboot, and force-stop still need **device** QA. See `docs/superpowers/qa-reports/` and DESIGN-GAP-MATRIX.

## Builds

`scripts/build_android_apk.sh` and `scripts/build_android_release_apk.sh` build the **production** flavor only:

```bash
flutter build apk --release --flavor production -t lib/main_production.dart
```

Package id: `com.recoskyler.pomo` (no suffix).

## Release signing (one keystore)

OTA updates require the **same release keystore** on every build. Copy `android/key.properties.example` to `android/key.properties` (gitignored) and point `storeFile` at your `.jks` file. CI can use `ANDROID_KEYSTORE_*` env vars (see `android/app/build.gradle`).

Without `key.properties`, release builds fall back to the debug keystore and cannot replace a signed install.

## OTA updates (personal Android installs)

| Asset | Host | Cost |
|-------|------|------|
| APK binary | [GitHub Releases](https://github.com/recoskyler/pomo/releases) | Free |
| `version.json` | Vercel `https://pomo-focus-sand.vercel.app/android/version.json` | Free tier |

On launch (production Android only), the app fetches `version.json`, compares `versionCode` to `pubspec` build number (`+N`), and offers download + install via `FileProvider`.

**Ship workflow:**

```bash
# Bump pubspec version first (e.g. 1.3.10+2)
./scripts/deploy_android_update.sh "Changelog here"
vercel deploy --prod   # publish version.json
```

One-time on device: Settings → allow **Install unknown apps** for Pomo.

Dart: `lib/services/app_update_service.dart`, `lib/widgets/settings_segments/android_app_update_tile.dart`. Native: `MainActivity` channel `com.recoskyler.pomo/app_update`, `FileProvider` in `AndroidManifest.xml`.

## Document history

| Date | Change |
|------|--------|
| 2026-09-08 | Production-only builds + GitHub/Vercel OTA channel |
| 2026-09-03 | Initial shipped Android spec |
