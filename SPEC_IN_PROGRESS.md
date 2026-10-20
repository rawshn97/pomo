# SPEC_IN_PROGRESS

**Parent index:** [`SPEC.md`](SPEC.md)  
**Rule:** Do not copy these into `specs/*.md` until the behavior is in `main` and verified.

This file tracks the active specification for the **Manual Time Log Editing, Week-To-Date & Custom Range Filters, and macOS Hourly Notification Removal** enhancements.

---

## 1. Manual Time Log Entry & Editing

### Problem
Users previously had to rely on the Focus timer or the deprecated hourly logging dialog to log time. When focus time happens away from the computer or phone, or when a session duration needs adjustment, there is currently no simple interface on the Time Log tab to record or adjust past focus logs.

### Requirements
1. **Manual Entry (`ManualTimeEntryDialog`):**
   - Affordance: "+ Add Time" button on the Time Log tab (`TrackerShellPage`).
   - Fields:
     - Date: Defaults to current date or selected date; editable via date picker.
     - Start Time & End Time: TimeOfDay pickers with automatic duration calculation.
     - Activity Tag: Selectable single tag from `Prefs.trackerTags`.
     - Optional notes.
   - Persistence:
     - Slices the time interval across hourly boundaries using `HourlyLogWriter.creditTimerMinutes`.
     - Saves records to `Prefs.hourlyLogs` and triggers immediate UI refresh via `Prefs.hourlyLogsRevision`.
     - Queues or synchronizes to Notion Hourly Timeline DB when Notion sync is enabled.
2. **Edit Existing Log (`EditTimeLogDialog`):**
   - Affordance: Tapping any logged activity chip in `_HourTimeline`.
   - Fields:
     - Duration in minutes: Editable via quick adjustments (-15m, -5m, +5m, +15m) or direct input.
     - Tag: Re-selectable from available `Prefs.trackerTags`.
     - Notes: Editable text.
     - Delete action: Deletes the log from `Prefs.hourlyLogs` (and archives Notion page if synced).
   - Persistence:
     - Updates `Prefs.hourlyLogs` and bumps `Prefs.hourlyLogsRevision`.
     - Updates Notion page via `NotionSyncService.syncHourlyLog`.

---

## 2. Removal of Hourly Reminder Notifications on macOS

### Problem
Hourly check-in reminder banners continue to trigger in macOS builds via `HookHelper._checkAndTriggerHourlyReminder` calling `LocalNotificationService.instance.showHourlyReminder`. Since manual hourly logging has been deprecated, these banners are redundant distractions.

### Requirements
1. Remove `LocalNotificationService.instance.showHourlyReminder` invocations from `HookHelper`.
2. Keep desktop notifications exclusively for timer events (work and break lap completions).
3. Update localization string for `enableDesktopNotificationsDescription` to: `"Notify when work or break laps end"`.

---

## 3. Time Log Analytics Filters: Week-to-Date & Custom Range

### Problem
The Time Log tab only offers fixed backward-looking periods (7, 14, 30, 90 days). Users need to view week-to-date focus time (Sunday through today) and arbitrary custom date ranges (e.g. specific project sprint or month).

### Requirements
1. **`TimeLogAnalyticsHelper` additions:**
   - `startOfWeekSunday(DateTime date)`: Returns the preceding Sunday (or same day if today is Sunday) at 00:00:00.
   - `analyzeDateRange`: Accepts explicit `DateTime start` and `DateTime end`, computes rollup metrics, daily summaries, tag breakdowns, and active streak.
2. **Filter UI on `TimeLogHistoryView`:**
   - Filter options:
     - `This Week`: Sunday through today.
     - `7 Days`, `14 Days`, `30 Days`, `90 Days`: Standard trailing windows.
     - `Custom Range`: Opens Flutter `showDateRangePicker` and renders custom date label (e.g., `Oct 1 - Oct 15`).

---

## 4. Multi-Platform Deployment Plan
1. **Verification:** `./scripts/verify.sh` (formatting, analysis, unit/widget tests).
2. **macOS:**
   - Compile production release bundle.
   - Remove existing `/Applications/Pomo.app`.
   - Copy fresh `Pomo.app` to `/Applications/`.
   - Package distribution DMG via `./build_macos_dmg.sh`.
3. **Android:**
   - Bump version to `1.4.1+5`.
   - Run `./scripts/deploy_android_update.sh`.
4. **Web PWA:**
   - Deploy to Vercel via global `vercel deploy --prod`.
5. **Git:** Commit and push to `origin/main`.
