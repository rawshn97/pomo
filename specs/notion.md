# Notion sync

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `lib/services/notion_service.dart`, `lib/services/notion_sync_service.dart`

---

## Purpose

Optional two-way-ish sync with the operator's PARA Notion workspace. HTTP via `dio`; optional `notionProxyUrl` for web (browser CORS).

Gated by `Prefs.enableNotionSync` plus API key (`secret_...` or shared access code).

## Databases (Settings)

| Setting | Role |
|---------|------|
| `notionDatabaseId` | Tasks (picker on Focus tab) |
| `notionTimeLogsDatabaseId` | Pomodoro / manual **session** rows |
| `notionProjectsDatabaseId` | Projects for hourly attach |
| `notionAreasDatabaseId` | Areas for hourly attach |
| `notionHourlyTimelineDatabaseId` | Hourly logs **and** activity-tag registry rows |

## Session logs (Time Logs)

`NotionSyncService.createSessionRecord` / `updateSessionRecord` / `deleteSessionRecord`.

Idempotency: stable `Prefs.activeSessionExternalId`. On retry, matching row still credits task cumulative time (`checkIdempotency` + patch). Sub-minute sessions are deleted on finalize.

Pending JSON: `Prefs.pendingTimeLogs`. Bootstrap flushes both pending queues on launch.

## Hourly logs (Hourly Timeline)

`syncHourlyLog`, `replaceHourlyLogsForHour` (slot reconciliation archives superseded/duplicate Notion pages), `pullHourlyLogs` (default 90 days), `flushPendingHourlyLogs`.

Pending JSON: `Prefs.pendingHourlyLogs`.

Pull-then-reconcile on bootstrap so PWA and desktop converge.

## Activity tag registry

Tags are **not** a separate Notion database. They are rows in Hourly Timeline with `Source = pomo-activity-tag`.

- `syncActivityTags`: bidirectional reconcile.
- `saveActivityTag` / `deleteActivityTag` / `reassignAndDeleteActivityTag`: local Prefs + registry / **tombstone** so other devices drop the tag.
- `_recoverTagsFromHourlyLogs`: rebuild custom tags from historical hourly rows after an upgrade; rewrites orphan logs to existing canonical names instead of creating duplicates.

## Tasks and projects

`NotionService` queries tasks for the modal; `queryProjectsAndAreas` for the hourly dialog. Status patch to In Progress when a To Do task starts on the timer.

## Web vs desktop

Web typically needs `notionProxyUrl` (see [web.md](web.md) and `deploy/` API). Desktop can call Notion with the token directly.

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial shipped Notion spec |
