# Development Context, Architectural Decisions & Roadmap Handoff

**Date:** 2026-10-22  
**Context:** Handoff documentation capturing all discussions, root cause investigations, shipped features, and pending specs from the October 2026 development session.  
**Branch:** `main`  
**Current Shipped Release:** `v1.4.7` (`versionCode: 11`)  
**Parent Specs:**
- [`SPEC.md`](../../../SPEC.md) (Shipped spec index)
- [`specs/remote-sync.md`](../../../specs/remote-sync.md) (Shipped cross-device sync spec)
- [`SPEC_IN_PROGRESS.md`](../../../SPEC_IN_PROGRESS.md) (Approved pending specifications)
- [`ARCHITECTURE.md`](../../../ARCHITECTURE.md) (System architecture)

---

## 1. Executive Summary

During this session, we addressed core architectural questions around Notion database redundancy, time tracking philosophy, background reminders, and real-time cross-device timer synchronization. We implemented a complete real-time WebSocket sync engine on Cloudflare Workers, resolved critical Android notification shade bugs, and released version `v1.4.7` with in-app OTA updates.

This document serves as the comprehensive source of truth for the next agent or fresh chat session to continue development seamlessly.

---

## 2. Key Discussions, Findings & Architectural Decisions

### 2.1 Time Logs vs Hourly Timeline (Do We Need Two Notion Databases?)
- **User Observation:** Sessions run with an Activity Tag selected (e.g. 😴 Sleep & Rest) without linking a specific Notion Task were saved to the Hourly Timeline and local Prefs, but completely bypassed the Time Logs database.
- **Root Cause:**
  - `NotionSyncService.logSession` explicitly requires a `taskId` to write to the `Time Logs` database, because the database schema is strictly relational (`Task`, `Project`, `Area`).
  - Sessions run purely with Activity Tags were handled by `HourlyLogWriter` and synced to the `Hourly Timeline` database.
- **Architectural Distinction:**
  - **Hourly Timeline:** 24-hour chronological calendar timeline, hourly slices, activity tag distribution, and tag registry.
  - **Time Logs:** Discrete task and project accounting linked to PARA entities (used in PARA weekly status reports).
- **User Direction & Philosophy:**
  - The Tracker tab should focus on showing total time spent on activities in a week/day and identifying unlogged slots ("the gaps"), rather than an intrusive hourly check-in grid.
  - PARA should only engage when a Task, Project, or Area is explicitly selected.
  - Tag management must be configured independently.
  - The "Select Task" button will be augmented into a 3-tier selector: Area/Resource -> Project -> Task.

---

### 2.2 Manual Time Logging: Overlap Handling & Multi-Tag Specification
- **User Question:** When logging time manually in the Tracker tab, how should overlapping time slices be handled?
- **Decision & Spec:**
  - In any 60-minute clock hour, total logged time across all tags must never exceed 60 minutes (no double-counting).
  - In a 60-minute window, the user cannot log 90 minutes of work.
  - When an overlap occurs, the UI displays a warning banner and provides two resolution strategies:
    1. **Equal-Split Merge (Default):** Appends time additively while capping the hour at 60m. Any excess overlapping duration ($\Delta = \sum \text{minutes} - 60$) is deducted equally across all active tags in that hour ($d_i = \lfloor \Delta / N \rfloor$).
       - *Example (30m overlap):* An existing 60m log + a new 30m log yields 90m total (30m excess). The 30m excess is split equally (15m deduction each), resulting in 45m for the existing log and 15m for the new log ($45m + 15m = 60m$).
    2. **Overwrite / Replace:** Replaces the conflicting log records in that time window with the new entry.
  - Detailed in `SPEC_IN_PROGRESS.md` Section 3.

---

### 2.3 Decommissioning Hourly Reminders Across All Platforms
- **User Issue:** Hourly reminders were still firing on Android devices at the top of every hour.
- **Root Cause:** While desktop reminder banners were removed on macOS, the native Android app still scheduled exact alarms via `AlarmManager` (`HourlyAlarmScheduler`, `HourlyAlarmReceiver`, `BootReceiver`).
- **Decision:** Fully decommission hourly reminders on all devices. Alarms will be cancelled and disabled in native Android code, and references removed from UI and settings.
- **Specification:** Detailed in `SPEC_IN_PROGRESS.md` Section 1.

---

### 2.4 Real-Time Cross-Device Timer Synchronization
- **User Request:** When a focus session runs on macOS, opening the Android app should immediately sync the timer and display the countdown in the Android notification shade.
- **Evaluation of Notion for Real-Time Sync:**
  - Notion API is strictly unsuitable for real-time countdown sync due to:
    1. Rate limits (3 requests per second).
    2. Network latency (400ms to 1200ms per request).
    3. Lack of WebSockets, Server-Sent Events, or push transport.
    4. Database revision bloat from frequent updates.
  - Verdict: Notion remains an asynchronous persistence store only.
- **Transport Selection:**
  - Evaluated Vercel serverless relay vs Cloudflare Edge Worker WebSockets vs GCE VM persistent daemon.
  - User selected Cloudflare Edge Worker for sub-20ms latency and instant push capability.
- **Implementation & Deployment:**
  - Built Cloudflare Worker with Durable Objects (`worker/src/index.js`, `worker/wrangler.toml`).
  - Deployed to: `https://pomo-sync.mishra-roshanraj.workers.dev` (WebSocket: `wss://.../ws`).
  - Created `RemoteSessionService` (`lib/services/remote_session_service.dart`) with WebSocket transport, reconnection logic, and REST polling fallback.
  - Created `RemoteSession` model (`lib/models/remote_session.dart`) implementing the Target Timestamp Model (`endsAt`, `liveRemaining`, `remainingSeconds`).
  - Created `RemoteSessionPresenceBanner` (`lib/widgets/remote_session_presence_banner.dart`) on TimerPage.

---

### 2.5 Android Notification Shade Debugging & Root Cause Resolution
- **User Issue:** After updating Android to v1.4.6, the app connected to the Cloudflare sync room, but no notification shade appeared on Android.
- **Root Cause Analysis:**
  - In `v1.4.6`, `RemoteSession.fromJson` attempted `(json['updatedAt'] as num).toInt()`.
  - The Cloudflare Edge Worker returned `updatedAt` as an ISO-8601 string (`"2026-10-21T11:30:19.395Z"`).
  - In sound null safety Dart, `String as num` threw a runtime `TypeError`: `type 'String' is not a subtype of type 'num?' in type cast`.
  - The incoming listener caught the exception in a generic `catch (e)` block and swallowed it, aborting before `remoteSessionNotifier.value = session` or `_syncAndroidNotification(session)` could execute.
- **Fixes Applied:**
  1. `RemoteSession.fromJson` updated to safely parse both ISO-8601 strings and numeric millisecond epochs, prioritizing `liveRemaining`.
  2. Added smooth 1-second countdown ticker in `RemoteSessionService._startRemoteTick(session)` to tick down locally and update the Android notification shade every second.
  3. Added `startForeground` safety try-catch with fallback to `NotificationManager.notify()` in `TimerForegroundService.kt` to ensure compatibility with Android 14+ background execution policies.
  4. Built and signed release APK `v1.4.7` (`versionCode: 11`) using the owner's release keystore (`~/Keys/pomo-release.jks`).
  5. Published GitHub Release `v1.4.7` with `pomo-production.apk` attached.
  6. Deployed Vercel production with updated `web/android/version.json`.

---

## 3. Inventory of Files Changed & Created

| File Path | Description of Changes |
|-----------|------------------------|
| `worker/src/index.js` | Cloudflare Worker + Durable Object WebSocket relay and REST state store |
| `worker/wrangler.toml` | Cloudflare Worker configuration |
| `lib/models/remote_session.dart` | RemoteSession model with Target Timestamp parsing and copyWith |
| `lib/services/remote_session_service.dart` | WebSocket client, REST fallback, and 1s local notification countdown ticker |
| `lib/widgets/remote_session_presence_banner.dart` | Presence pill banner on TimerPage displaying active remote session |
| `android/app/src/main/kotlin/com/recoskyler/pomo/TimerForegroundService.kt` | Android FGS start safety try-catch with notify fallback |
| `test/models/remote_session_test.dart` | Unit tests for RemoteSession ISO-8601 parsing and countdown logic |
| `test/services/remote_session_service_test.dart` | Unit tests for RemoteSessionService connection and notifications |
| `pubspec.yaml` | Bumped version to `1.4.7+11` |
| `web/android/version.json` | Updated versionCode to 11 and versionName to 1.4.7 for in-app OTA updater |
| `specs/remote-sync.md` | Shipped technical specification for cross-device real-time sync |
| `SPEC.md` | Updated shipped spec index and capabilities list |
| `SPEC_IN_PROGRESS.md` | Updated roadmap status (Item 4 shipped; Items 1, 2, 3 pending) |
| `ARCHITECTURE.md` | Updated architecture diagram and added Section 12 on Remote Sync |

---

## 4. Roadmap & Next Steps for the Fresh Chat Session

When starting the next chat session, tackle the remaining pending items from `SPEC_IN_PROGRESS.md`:

### Priority 1: Decommission Hourly Reminders on Mobile & Desktop
- **Reference:** `SPEC_IN_PROGRESS.md` Section 1.
- **Tasks:**
  1. In `android/app/src/main/kotlin/com/recoskyler/pomo/MainActivity.kt`, invoke `HourlyAlarmScheduler.cancel(this)` on startup and remove scheduling triggers.
  2. In `HourlyAlarmScheduler.kt`, decommission `scheduleNextHour` and `schedule`.
  3. In `BootReceiver.kt`, remove alarm rescheduling on device reboot.
  4. In `HourlyAlarmReceiver.kt`, remove automatic re-arming of subsequent alarms.
  5. In `lib/helpers/hook_helper.dart`, remove calls to `scheduleNextHourlyAlarm()`.
  6. In `lib/pages/settings/cubit/settings_cubit.dart`, remove calls to `scheduleNextHourlyAlarm()`.
  7. Update localization strings in `lib/l10n/app_en.arb` to eliminate obsolete references to hourly reminders.

### Priority 2: Manual Time Logging Overlap Resolution
- **Reference:** `SPEC_IN_PROGRESS.md` Section 3.
- **Tasks:**
  1. In `ManualTimeEntryDialog` (`lib/widgets/manual_time_entry_dialog.dart`), calculate requested interval $[T_{start}, T_{end}]$ against existing `Prefs.hourlyLogs`.
  2. Render amber visual warning banner if overlap is detected with total conflicting minutes.
  3. Implement Equal-Split Merge algorithm: cap 60m clock hour and deduct excess overlap equally across active tags ($d_i = \lfloor \Delta / N \rfloor$).
  4. Add unit tests in `test/helpers/` verifying 30m and 60m overlap scenarios.

### Priority 3: Augmented Focus Target Hierarchy (Area/Resource -> Project -> Task)
- **Reference:** `SPEC_IN_PROGRESS.md` Section 2.
- **Tasks:**
  1. Replace flat task selector with `NotionParaSelectorModal` offering 3-tier drilldown: Area/Resource -> Project -> Task.
  2. Allow user to track time at Area level, Project level, or specific Task level.
  3. Update `TimerState` and `NotionSyncService.logSession` to support Area and Project relations without requiring a Task.

---

## 5. Verification & Deployment Rails Reminder
- Always run `./scripts/verify.sh` before committing (must pass formatting, very_good_analysis, and 218+ unit tests).
- Follow the auto-deploy rule: commit, push to GitHub, and deploy to Vercel production before notifying the user.
- Strictly avoid the em dash character (U+2014) in all files, comments, commits, and UI strings.
