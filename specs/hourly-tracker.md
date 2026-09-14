# Time log history (formerly hourly tracker)

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `lib/pages/tracker/`

---

## Purpose

Tab 1 is a **read-only** history and analytics view for timer-credited activity logs. Manual hourly logging and missed-hour catch-up were removed; focus time is recorded by selecting activity tags on the Focus tab before starting the timer (see [timer.md](timer.md)).

## Shell (`TrackerShellPage`)

Single view: **Time Log** (`TimeLogHistoryView`).

App bar can open the Notion Hourly Timeline database in the browser when sync is on. Android may show `AndroidTrackerStatusPrompt` (battery / alarm status).

## Data source

Rows are `HourlyLog` entries in `Prefs.hourlyLogs`, written by `HourlyLogWriter.creditTimerMinutes()` when the Focus timer pauses, changes lap, resets, or switches tasks. Auto-filled quiet-hour Resting rows are excluded from focus analytics.

Optional Notion pull on load keeps local history in sync with the Hourly Timeline database.

## Analytics (`TimeLogAnalyticsHelper`)

Pure helpers in `lib/helpers/time_log_analytics_helper.dart`:

- Total focus time, daily average, active days, current streak
- Tag breakdown (% share and minutes)
- Peak focus hours (hour-of-day pattern across the selected period)
- Per-day summaries with top tag
- Per-day hour timeline (read-only)

Period presets: 7, 14, 30, 90 days. Tap a day in Daily History or use date navigation to inspect a single day.

## Tags

Tag create/delete remains on the Focus tab (`TimerTagBar` + `TagCreateDialog` / `TagDeleteDialog`). Stored in `Prefs.trackerTags`.

## Notifications

Hourly reminder actions (`OpenTrackerAction`, `HourlyLogAction`, `HourlyInstantWriteAction`) open the Time Log tab only. They no longer open a manual log dialog or write instant Deep Work rows.

## Quiet hours / Resting

If `enableQuietHours`, `HourlyLogWriter.reconcileResting` still fills empty quiet-hour slots locally with Sleep & Rest (`tag_sleep`, notes `Resting`). These rows are hidden from focus analytics.

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial shipped hourly tracker spec |
| 2026-09-14 | Decommission manual hourly logging; replace with read-only Time Log analytics |
