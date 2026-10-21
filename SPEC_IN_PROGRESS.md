# SPEC_IN_PROGRESS

**Parent index:** [`SPEC.md`](SPEC.md)  
**Rule:** Do not copy these into `specs/*.md` until the behavior is in `main` and verified.

This document outlines the architectural specifications for four new capabilities:
1. Complete Decommissioning of Hourly Check-in Reminders on Mobile & Desktop
2. Augmented Focus Target Hierarchy (Area / Resource -> Project -> Task Selector)
3. Manual Time Logging: Overlap Detection, Resolution & Multi-Tag Specification
4. Real-Time Cross-Device Timer Synchronization Architecture (macOS <-> Android)

---

## 1. Decommissioning Hourly Reminders Across All Platforms

### Problem
Hourly check-in reminders were originally built for manual 24-hour hourly logging, prompting the user at the top of every hour to record what they were doing. With the transition to timer-driven focus sessions and retrospective manual entry on the Time Log tab, these check-in banners are obsolete and intrusive. While desktop reminder banners were removed on macOS, the native Android app still schedules exact alarms via `AlarmManager` (`HourlyAlarmScheduler`), causing unwanted notifications on mobile.

### Requirements
1. **Cancel & Disable Android AlarmManager Alarms:**
   - In `MainActivity.kt`, invoke `HourlyAlarmScheduler.cancel(this)` on startup and remove scheduling triggers.
   - Decommission `HourlyAlarmScheduler.scheduleNextHour` and `HourlyAlarmScheduler.schedule`.
   - In `BootReceiver.kt`, remove the alarm rescheduling on device reboot (`ACTION_BOOT_COMPLETED`).
   - In `HourlyAlarmReceiver.kt`, remove automatic re-arming of subsequent hourly alarms.
   - In `HookHelper.dart`, eliminate all calls to `AndroidNotificationService().scheduleNextHourlyAlarm()`.
   - In `SettingsCubit.dart`, remove calls to `scheduleNextHourlyAlarm()`.
2. **Channel & Notification Cleanliness:**
   - Keep notification ID `1001` (`TimerForegroundService`) for active timer countdowns.
   - Decommission notification ID `1002` (`hourly_tracker_v2` shade check-in).
3. **UI & Settings Alignment:**
   - Update `app_en.arb` strings:
     - Change `enableQuietHoursDescription` from `"Silence unattended hourly reminders during the selected time range"` to `"Silence timer alerts during the selected time range"`.
     - Remove obsolete references to "hourly reminders" in battery optimization tiles and permission rationale prompts (`AndroidTrackerStatusPrompt`).
   - Retain Quiet Hours purely for auto-filling resting/sleep blocks locally and muting timer completion sounds.

---

## 2. Augmented Focus Target Hierarchy (Area/Resource -> Project -> Task)

### Problem
Currently, the timer only supports linking to a flat list of Notion Tasks via the "Select Task" modal. In the PARA method, focus time frequently belongs to a broader Area or Resource (e.g. `🏋️ Fitness`, `🎧 DJing`, `📚 System Architecture`) or to a Project (e.g. `Pomo Timer Overhaul`) without requiring a granular Task page. Users need the flexibility to track time at any level of the PARA hierarchy.

### Requirements
1. **Multi-Tier Selection Modal (`NotionParaSelectorModal`):**
   - Replaces the flat `NotionTasksModal` with a 3-tier hierarchical drill-down:
     - **Tier 1: Areas & Resources:** Lists active Areas and Resources from the Areas database (`Prefs.notionAreasDatabaseId`).
       - Affordance: "Track time on this Area/Resource" (stops selection here).
       - Drilling down: Tapping navigates to Projects linked to this Area.
     - **Tier 2: Projects:** Lists Projects from `Prefs.notionProjectsDatabaseId` belonging to the selected Area (or all active projects).
       - Affordance: "Track time on this Project" (stops selection here).
       - Drilling down: Tapping navigates to Tasks linked to this Project.
     - **Tier 3: Tasks:** Lists active Tasks from `Prefs.notionDatabaseId` linked to the selected Project.
       - Tapping selects the specific Task.
   - Quick Search bar: Allows instant global search across all Tasks, Projects, and Areas simultaneously.
2. **Timer State Representation:**
   - Update `TimerState` to support:
     - `activeArea`: Name/ID of the selected Area or Resource.
     - `activeProject`: Name/ID of the selected Project.
     - `activeTask`: The specific `NotionTask` (if selected).
   - Display on `TimerPage`:
     - If Task selected: `${task.title} (${project.title})`
     - If Project only selected: `📁 ${project.title} (${area.title})`
     - If Area only selected: `🏔️ ${area.title}`
     - If none: `"Select Focus Target"`
3. **Notion Sync & Time Logs Mapping:**
   - When writing to `Time Logs` (`NotionService.logSession`):
     - If Task is linked: Set `Task` relation (Notion automatically rolls up `Project` and `Area`).
     - If Project only is linked: Set `Project` relation or title, leaving Task empty.
     - If Area only is linked: Set `Area` relation or title.
     - Fallback title formatting:
       - Task level: `${minutes}m - ${task.title}`
       - Project level: `${minutes}m - [Project] ${project.title}`
       - Area level: `${minutes}m - [Area] ${area.title}`
       - Untasked: `${minutes}m - ${primaryTag.name}`

---

## 3. Manual Time Logging: Overlap Detection & Multi-Tag Specification

### Problem
In the Time Log tab, users can retroactively add past focus blocks using `ManualTimeEntryDialog`. Currently, if a user specifies a time range (e.g. 14:00 to 15:30) that overlaps with an already-logged focus session, there is no visual indicator or resolution mechanism, potentially leading to accidental double-counting or uncoordinated slot replacement. Furthermore, when multiple tags are selected, the system divides the duration equally, but the behavior during overlapping slots requires explicit specification.

### Requirements
1. **Real-Time Overlap Detection:**
   - As the user changes Date, Start Time, or End Time in `ManualTimeEntryDialog`:
     - Query local `Prefs.hourlyLogs` for the target date.
     - Compute the requested interval: $[T_{start}, T_{end}]$ with total duration $D_{total} = T_{end} - T_{start}$ minutes.
     - Identify any existing non-resting logs that intersect with the interval.
2. **Visual Overlap Warning Banner:**
   - If one or more existing logs overlap:
     - Render an amber warning banner inside the dialog:
       `⚠️ Overlaps with existing log: 14:00 - 14:45 💻 Code & Dev (45m)`
     - Show total overlapping minutes.
3. **Resolution Strategy:**
   - Offer a 2-option resolution selector when overlap is detected:
     - **Option A: Equal-Split Merge (Default):**
       - The new time is merged alongside existing logs without deleting them.
       - Core invariant: In any 60-minute clock hour, total logged time across all tags must never exceed 60 minutes (no double-counting).
       - If $\sum \text{minutes} \le 60$, all tags retain their requested duration.
       - If $\sum \text{minutes} > 60$, the excess overlapping duration $\Delta = \sum \text{minutes} - 60$ is deducted equally across all active tags in that hour ($d_i = \lfloor \Delta / N \rfloor$).
       - Example (30m overlap): An existing 60m log + a new 30m log in the same hour yields 90m total ($30m$ excess). The $30m$ overlap is split equally ($15m$ deduction each), resulting in $45m$ for the existing log and $15m$ for the new log ($45m + 15m = 60m$).
       - Example (60m full overlap): Two 60m logs in the same hour split 50/50 ($30m$ each).
     - **Option B: Overwrite / Replace:**
       - Conflicting log records in that time window are purged before logging the new entry.
       - The new tag(s) take the full requested duration.
4. **Multi-Tag Splitting Rules:**
   - When $N$ tags are selected ($N \ge 2$):
     - Total duration $D_{total}$ is divided equally: $D_{tag} = \lfloor D_{total} / N \rfloor$ minutes per tag (with remainder assigned to the primary tag).
     - Slicing: Time is apportioned across the target hour slots proportionally.
     - Overlap check: Each hour block is capped at 60m with excess overlapping time divided equally among active tags.

---

## 4. Real-Time Cross-Device Timer Synchronization Architecture

### 4.1 Evaluation of Notion for Real-Time Sync
Can Notion handle real-time timer synchronization between mobile and desktop?

**Verdict: NO.** Relying on Notion for real-time timer sync is fundamentally unsuitable due to the following technical constraints:
1. **Rate Limiting:** Notion API enforces an average rate limit of **3 requests per second** per integration token. A ticking or syncing timer cannot poll or write without quickly encountering HTTP 429 (Rate Limit Exceeded) errors.
2. **Network Round-Trip Latency:** Notion API calls have an average response time of **400ms to 1200ms**. Sub-second countdown synchronization is impossible over HTTP database queries.
3. **Lack of Push Transport:** Notion has no WebSockets, Server-Sent Events (SSE), or real-time client push mechanisms. Every state check requires an active HTTP POST/GET poll.
4. **Database & Revision Pollution:** Updating a Notion page state every few seconds would generate thousands of page revision history entries and database write locks, severely degrading workspace performance.

*Conclusion:* Notion must remain strictly an **asynchronous persistence store** for finalized session records and periodic analytical rollups.

---

### 4.2 The Target Timestamp Model (Mathematical Sync)
Real-time timer synchronization does **not** require transmitting every ticking second over the network. Instead, devices synchronize state transitions using the **Target Timestamp Model**:

```json
{
  "deviceId": "macbook_air_m5",
  "deviceName": "macOS",
  "status": "running",
  "lap": "work",
  "lapNumber": 1,
  "startedAt": "2026-10-21T14:00:00.000Z",
  "endsAt": "2026-10-21T14:25:00.000Z",
  "totalSeconds": 1500,
  "remainingSecondsOnPause": null,
  "activeTask": { "id": "task_123", "title": "Pomo Overhaul" },
  "activeTags": [{ "id": "tag_code", "name": "Code & Dev", "icon": "💻" }]
}
```

#### State Transition Logic:
1. **Start / Resume:** Emits single packet with `endsAt = now() + remainingDuration`.
2. **Remote Device (Android) on Launch / Wake:**
   - Reads packet.
   - Calculates local remaining seconds:
     $$\text{remaining} = \text{endsAt} - \text{DateTime.now()}$$
   - If $\text{remaining} > 0$ and `status == "running"`:
     - Android starts local countdown from `remaining`.
     - Android triggers `TimerForegroundService.startService` with title, activity tag, and task.
     - The native Android notification shade shows the active countdown tile immediately.
3. **Pause:** Emits `status = "paused"`, `remainingSecondsOnPause = N`. Both devices freeze countdown at $N$.
4. **Stop / Reset:** Emits `status = "idle"`. Both devices stop foreground services and clear notifications.

---

### 4.3 Transport Alternatives Leveraging Rawshn's Tech Assets

From `TECH_ASSETS_SUMMARY.md` (Audited October 2026), three zero-cost infrastructure assets are available:

#### Option 1: Vercel Serverless Relay (`api/session.js`) - [Currently Active]
- **Location:** Hosted on `pomo-focus-sand.vercel.app` (Vercel Hobby Tier).
- **Latency:** ~50ms to 120ms.
- **Cost:** Zero. Within 100k daily function invocations.
- **How it works:**
  - Active device POSTs heartbeat state on transition + every 10s.
  - Receiving device polls on app launch / resume, or connects via Server-Sent Events (SSE).
  - Memory cache with 45s auto-expiry.
- **Pros:** Zero new dependencies; already deployed in `v1.4.3`.
- **Cons:** Serverless instances spin down if idle for >10 minutes; requires active heartbeat.

#### Option 2: Cloudflare Edge Worker with WebSockets - [Lowest Latency & Push]
- **Location:** `rawshn.com` under Cloudflare Registrar and Workers Free Tier.
- **Latency:** Sub-20ms edge latency globally.
- **Cost:** Zero (within 100,000 free requests/day).
- **How it works:**
  - Cloudflare Worker maintains an open WebSocket channel between the macOS desktop app and the Android app.
  - When the timer starts on macOS, it pushes the state payload down the WebSocket to Android in <20ms.
- **Pros:** True instant push; zero polling; instant notification on phone.
- **Cons:** Requires deploying a Cloudflare Worker script.

#### Option 3: Persistent Daemon on GCE Always Free VM (`e2-micro`)
- **Location:** GCP project `cogent-jetty-490213-b2` in `us-central1-a` (running Debian 12 24/7).
- **Latency:** ~80ms.
- **Cost:** Always Free Tier ($0/month).
- **How it works:**
  - Runs a lightweight Node.js/Go WebSocket or MQTT broker exposed securely via Cloudflare Tunnel (`sync.rawshn.com`).
  - Android and macOS clients maintain a lightweight persistent socket.
- **Pros:** Full server control, persistent state in Redis/SQLite, no cold starts.

### Recommended Path:
1. **Phase 1 (Immediate):** Enhance the existing Vercel relay (`api/session.js`) with the Target Timestamp Model (`endsAt`). When Android launches or resumes, it fetches the active session, computes remaining time, and starts the native Android notification shade.
2. **Phase 2 (True Push):** Deploy a Cloudflare Worker WebSocket gateway on `sync.rawshn.com` for instant real-time push to the Android notification shade even when the Android app is closed.
