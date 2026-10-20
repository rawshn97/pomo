# SPEC_IN_PROGRESS

**Parent index:** [`SPEC.md`](SPEC.md)  
**Rule:** Do not copy these into `specs/*.md` until the behavior is in `main` and verified.

This file tracks the active specifications for:
1. Android Notification UX Overhaul (Activity Tag & Task Surfacing, BigTextStyle, Action Controls)
2. Cross-Device Focus Presence in UI (Live Session Relay, Presence Pill/Banner)
3. Notion Time Logs Untasked Session Syncing & Open-Source Cleanliness

---

## 1. Android Notification UX Overhaul

### Problem
The ongoing timer notification on Android only showed the countdown time and generic session name (`Work Session`), omitting the user's active activity tag (e.g. `😴 Sleep & Rest`) and active Notion task. Furthermore, when paused, the action title said `Play` instead of the Android standard `Resume`.

### Requirements
1. **Collapsed Notification:**
   - `subText`: `Focus Timer • Lap #N`
   - `contentTitle`: `24:40` when running, or `24:40 (Paused)` when paused.
   - `contentText`: `${tag} • ${task}` (or `${tag} • ${lapText}`, `${task} • ${lapText}`, or `${lapText}`).
2. **Expanded View (`NotificationCompat.BigTextStyle`):**
   - Multi-line structured readout:
     - `Activity: 😴 Sleep & Rest`
     - `Task: Task title` (or `No task selected`)
     - `Session: Work Session (Lap #1)`
3. **Actions:**
   - Running: `Pause` (`ic_media_pause`) and `Stop` (`ic_delete`).
   - Paused: `Resume` (`ic_media_play`) and `Stop` (`ic_delete`).
4. **Cleanliness:**
   - Remove dead custom layout `notification_timer.xml`.

---

## 2. Cross-Device Focus Presence in UI

### Problem
When a user begins a focus session on mobile or laptop, other linked devices (e.g. macOS desktop app or Web PWA) lacked any indication that a focus session was currently underway on their account.

### Requirements
1. **Serverless Presence Relay (`/api/session`):**
   - Authenticated endpoint on Vercel proxy accepting `FOCUS_ACCESS_TOKEN` or Notion token.
   - `POST /api/session`: Ingests heartbeat state (`deviceId`, `deviceName`, `status`, `lap`, `lapNumber`, `remainingSeconds`, `totalSeconds`, `tagName`, `tagIcon`, `taskTitle`).
   - `GET /api/session`: Returns `{ active: true, session: ... }` if a session was reported within 45 seconds; otherwise `{ active: false }`.
   - `DELETE /api/session`: Immediately clears session upon timer stop or reset.
2. **Client Polling & Broadcasting (`RemoteSessionService`):**
   - Active device broadcasts heartbeat every 10 seconds while running.
   - Idle device polls every 10 seconds and notifies `RemoteSessionPresenceBanner`.
   - Ignores heartbeats originating from the local device (`Prefs.deviceId`).
3. **Presence UI Banner (`RemoteSessionPresenceBanner`):**
   - Displayed on `TimerPage` when local timer is idle and remote session is active.
   - Displays device badge (`Mobile is focusing`, `macOS is focusing`), counting down remaining time, tag chip, and task details.
   - Hides automatically when local timer begins running or remote session stops.

---

## 3. Notion Time Logs Untasked Session Syncing & Open-Source Cleanliness

### Problem
Notion `Time Logs` table stopped recording sessions after October 4 because `TimerCubit._createNotionRecord` strictly checked `if (state.activeTask == null) return;`. Recent focus time was logged only with activity tags into `Hourly Timeline` and local storage, leaving `Time Logs` incomplete for untasked sessions.

### Requirements
1. **Untasked Time Log Creation:**
   - `NotionService.logSession` allows optional `task` parameter and uses `sessionTitle` (`"${minutes}m - ${tagName}"`).
   - Slices row to `Time Logs` without task relation when `activeTask` is null.
   - Skips patching task cumulative time when no task is linked.
2. **TimerCubit Integration:**
   - `_createNotionRecord`, `_updateNotionRecord`, and `_finalizeSession` record all work sessions to `Time Logs`, populating primary tag display.
3. **Open-Source Readiness:**
   - Verify zero credentials, private Notion tokens, or personal database IDs are hardcoded in the codebase.
