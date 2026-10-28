# Focus timer and PARA task sessions

**Parent index:** [`../SPEC.md`](../SPEC.md)  
**Module path:** `lib/pages/timer/`, `lib/pages/tasks/`, `lib/services/timer_tick_service.dart`

---

## Purpose

Tab 0 is the original Pomodoro: work and break laps, circular progress, sounds, webhooks, optional binding to a **Notion PARA task**, and optional **hourly activity tags**. Elapsed work time can write **Time Logs** rows and bump task `Time (hours)` / minutes. Selected tags receive additive minutes on the hourly grid.

## UI (`TimerPage`)

- Circular progress + countdown (`TimerProgress`, `TimerText`).
- **Activity tag chips** (`TimerTagBar`): multi-select hourly tags; add tag; delete custom tags via reassign dialog. Tag changes are blocked while a work lap is running.
- Action buttons: start/pause, skip lap, reset (`widgets/timer/action_buttons.dart`).
- **Select Task** pill: opens `NotionTasksModal`; optional **Log past time** (`ManualLogDialog`) when a task is selected; clear task.
- Keyboard: Space/Enter toggle, `s` skip, `r` / Backspace reset.

## State (`TimerCubit` / `TimerState`)

| Field | Meaning |
|-------|---------|
| `status` | `running` / `stopped` |
| `duration` | elapsed in current lap |
| `lap` | `work` / `shortBreak` / `longBreak` |
| `lapNumber` | session index |
| `activeTask` | selected `NotionTask` (also in Prefs) |
| `activeLogPageId` | open Time Logs page for this work session |
| `activeTags` | selected `TrackerTag`s for hourly credit (`Prefs.lastTimerTagIds`) |

Ticks: `TimerTickService` / page timer → `tick(settingsState)` (+1s). Lap complete uses `DurationHelper` vs Settings durations. `autoAdvance` either starts the next lap or stops.

Persistence: every tick writes `Prefs.duration` so a kill/restart can resume.

## Notion task session (gated)

Requires `enableTimeTracker`, a selected task, and **work** lap:

| Event | Behavior |
|-------|----------|
| First start of work lap | `createSessionRecord` (idempotent `activeSessionExternalId`) |
| Pause (`stop`) | `updateSessionRecord` if elapsed ≥ 1 minute |
| Reset / skip lap / change or clear task | `_finalizeSession`: delete if &lt; 1 min else update |
| Task was To Do | fire-and-forget `moveToInProgressIfNeeded` |

Offline failures enqueue `Prefs.pendingTimeLogs`. Flush via `NotionSyncService.flushPendingLogs`.

Manual log: hours + minutes + date against the selected task (does not write hourly tags).

## Hourly tag credit (Approach A)

Work laps only. Requires `enableTimeTracker` and at least one selected tag. Credits **delta minutes** (`duration.inMinutes` minus already credited) on pause, lap change, reset, and task change.

Equal split across selected tags (`TimerTagCreditHelper.splitEqually`; first tag gets remainder). Wall-clock hour boundaries (`sliceByHour`). Additive merge into existing hour rows; auto-fill Resting (`notes == Resting`) is replaced. Totals may exceed 60m. Helpers: `lib/helpers/timer_tag_credit_helper.dart`, persist via `HourlyLogWriter.creditTimerMinutes`.

Duplicate tag names are blocked in `TagCreateDialog`. Built-in tags cannot be deleted.

Task list: `NotionTasksCubit` queries Tasks (`notionDatabaseId`) and active projects via `queryActiveProjects` (`notionProjectsDatabaseId`). Areas, resources, and archived items are excluded from task selection.

## Sounds and webhooks

`TimerPage` plays sounds through `SoundHelper` when `enableSound` is on. Lap start/end types skip if they would double-fire against current status.

`HookHelper` posts `{ "rgb": [r,g,b] }` to configured URLs when webhooks are enabled (start/stop/reset/tick/lap URLs, comma-separated, `dio`).

## Platforms

Same Dart UI on **macOS, Android, and web**. Platform extras:

- macOS overlay is a **display-only** second window (see [desktop.md](desktop.md)); it does not host the task picker.
- Android timer notification Play/Pause/Stop calls into the same `TimerCubit` (see [android.md](android.md)).
- Web can show lap notifications / PiP via `WebPwaService` (see [web.md](web.md)).

## Tests

`test/blocs/timer_cubit_test.dart` and related helper tests. Flavor: `flutter test --flavor development`.

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | Initial shipped timer spec |
| 2026-09-03 | Timer credits hourly activity tags (Approach A) |
