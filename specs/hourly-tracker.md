# Time log history (formerly hourly tracker)

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `lib/pages/tracker/`

---

## Purpose

Tab 1 is an activity history and analytics view for focus logs. Focus time is recorded automatically by selecting activity tags on the Focus tab before starting the timer (see [timer.md](timer.md)), or logged manually via the manual time entry dialog. Existing records can be edited or deleted directly from the daily timeline.

## Shell (`TrackerShellPage`)

Single view: **Time Log** (`TimeLogHistoryView`).

App bar offers:
- **Add focus time manually** (`ManualTimeEntryDialog`): Choose date, start time, end time, and activity tag. Minutes are sliced across hours via `HourlyLogWriter.creditTimerMinutes`.
- **Open Notion Hourly Timeline**: Opens database in the browser when Notion sync is enabled.
- Android may show `AndroidTrackerStatusPrompt` (battery / alarm status).

## Data source

Rows are `HourlyLog` entries in `Prefs.hourlyLogs`, written by `HourlyLogWriter.creditTimerMinutes()` when the Focus timer credits laps, or when added manually via `ManualTimeEntryDialog`. Auto-filled quiet-hour Resting rows are excluded from focus analytics.

`Prefs.hourlyLogsRevision` bumps on every local write (including manual adds, edits, and deletions via `Prefs.deleteHourlyLog`) so `TimeLogHistoryView` refreshes immediately. Opening the Time Log tab also re-reads Prefs via `AppNavigationController.currentTabIndex`.

Optional Notion pull on first load / pull-to-refresh keeps local history in sync with the Hourly Timeline database.

## Analytics & Filters (`TimeLogAnalyticsHelper`)

Pure helpers in `lib/helpers/time_log_analytics_helper.dart`:

- Total focus time, daily average, active days, current streak
- Tag breakdown (% share and minutes)
- Peak focus hours (hour-of-day pattern across the selected period)
- Per-day summaries with top tag
- Per-day hour timeline with interactive tap-to-edit (`EditTimeLogDialog`)

Filter options:
- **This Week**: Sunday through current date via `TimeLogAnalyticsHelper.startOfWeekSunday`.
- **Presets**: 7, 14, 30, 90 days.
- **Custom Range**: Custom start and end date selection via Flutter `showDateRangePicker`.

## Editing & Deleting Logs

Tapping any activity badge on the daily hour timeline opens `EditTimeLogDialog`:
- Change duration (quick adjustment chips -15m, -5m, +5m, +15m or slider).
- Reassign activity tag.
- Edit notes.
- Delete log (removes from `Prefs.hourlyLogs` and archives Notion row if synced).

## Tags

Tag create/delete remains on the Focus tab (`TimerTagBar` + `TagCreateDialog` / `TagDeleteDialog`). Stored in `Prefs.trackerTags`.

## Notifications

Hourly check-in reminder banners have been removed from macOS; desktop notifications fire exclusively when timer laps end.

## Quiet hours / Resting

If `enableQuietHours`, `HourlyLogWriter.reconcileResting` still fills empty quiet-hour slots locally with Sleep & Rest (`tag_sleep`, notes `Resting`). These rows are hidden from focus analytics.

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial shipped hourly tracker spec |
| 2026-09-14 | Decommission manual hourly logging; replace with read-only Time Log analytics |
| 2026-09-14 | Live refresh after Focus timer credits (`hourlyLogsRevision` + tab select) |
| 2026-10-21 | Add manual time log entry, edit/delete dialogs, week-to-date and custom range filters |
