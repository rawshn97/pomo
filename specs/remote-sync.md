# Remote Session & Real-Time Sync Specification

**Spec file:** `specs/remote-sync.md`  
**Parent index:** [`SPEC.md`](../SPEC.md)  
**Shipped in:** `v1.4.6` (initial WebSocket relay), `v1.4.7` (payload deserialization fix + 1-second local notification tick), `v1.4.8` (omnidirectional 3-way sync, macOS menu bar sync, PWA dynamic title, session takeover), `v1.4.9` (bidirectional takeover bugfix & displaced device guard), `v1.5.1` (active task and activity tags migration during cross-device takeover)  
**Related files:**
- `worker/src/index.js` (Cloudflare Worker + Durable Objects WebSocket relay)
- `worker/wrangler.toml` (Cloudflare Worker configuration)
- `lib/models/remote_session.dart` (Data model with Target Timestamp parsing, NotionTask reconstruction, and tags list)
- `lib/services/remote_session_service.dart` (WebSocket client, REST polling fallback, local 1-second countdown ticker)
- `lib/widgets/remote_session_presence_banner.dart` (Timer tab remote session presence pill with Take Over button)
- `lib/pages/timer/cubit/timer_cubit.dart` (takeOverRemoteSession implementation and state adoption)
- `android/app/src/main/kotlin/com/recoskyler/pomo/TimerForegroundService.kt` (Android notification shade sync)

---

## 1. Problem Statement

Operators frequently switch between their desktop workstation (macOS), mobile phone (Android), and browser workstations (Web PWA). When a focus sprint begins on one device, all other devices must:
1. Immediately reflect the active countdown in UI banners, system menu bars, notification shades, or browser tab titles without duplicate timers or manual polling.
2. Enable seamless cross-device session takeover where any device can adopt the active countdown, Notion task context, and activity tags in one tap.

### Why Notion Is Not Used for Real-Time Sync
Notion API is strictly an asynchronous persistence layer:
1. Average rate limit of 3 requests per second per integration token.
2. HTTP round-trip latency of 400ms to 1200ms.
3. No WebSocket, SSE, or client push mechanism.
4. Frequent updates create thousands of revision records and database write locks.

---

## 2. Architecture & Data Flow

```
+-----------------------------------------------------------+
|              macOS / Android / Web PWA Client             |
|  - TimerCubit runs focus session                          |
|  - Posts state transitions & heartbeats to Cloudflare WS  |
+-----------------------------+-----------------------------+
                              |
                              | WSS / HTTPS (sub-20ms)
                              v
+-----------------------------------------------------------+
|       Cloudflare Edge Worker (pomo-sync)                  |
|  - URL: https://pomo-sync.mishra-roshanraj.workers.dev    |
|  - WebSocket: wss://.../ws                                |
|  - Durable Object: SyncRoom (in-memory state persistence)  |
|  - Computes: liveRemaining = max(0, endsAt - now())       |
|  - Sub-20ms fanout to all connected peer clients          |
|  - Displaced device guard against stale stop/pause packets|
+-----------------------------+-----------------------------+
                              |
                              | Push over WebSocket
                              v
+-----------------------------------------------------------+
|               Peer Devices (Android / macOS / Web)        |
|  - RemoteSessionService receives session packet           |
|  - Starts local 1s countdown ticker (_startRemoteTick)    |
|  - Android: Updates notification shade via FGS            |
|  - macOS: Displays live countdown in native Menu Bar item |
|  - Web: Displays live countdown in document tab title     |
|  - Timer tab: Renders RemoteSessionPresenceBanner         |
|  - Tapping "Take Over" adopts duration, task, and tags    |
+-----------------------------------------------------------+
```

---

## 3. The Target Timestamp Model

Real-time timer synchronization does not send every ticking second over the network. Instead, devices synchronize state transitions and rely on wall-clock target timestamps:

```json
{
  "deviceId": "dev_1792561929724_646095",
  "deviceName": "macOS",
  "status": "running",
  "lap": "work",
  "lapNumber": 1,
  "remainingSeconds": 1326,
  "totalSeconds": 1500,
  "tagName": "Deep Work",
  "tagIcon": "🧠",
  "tagColorHex": "#00F0FF",
  "tagId": "tag_deep_work",
  "tags": [
    {
      "id": "tag_deep_work",
      "name": "Deep Work",
      "icon": "🧠",
      "colorHex": "#00F0FF"
    }
  ],
  "taskTitle": "Ship v1.5.1 documentation audit",
  "taskId": "task_12345",
  "taskJson": "{\"id\":\"task_12345\",\"title\":\"Ship v1.5.1 documentation audit\"}",
  "updatedAt": "2026-10-22T14:30:19.395Z",
  "endsAt": "2026-10-22T14:52:25.395Z",
  "liveRemaining": 1326,
  "isRunning": true
}
```

### Invariants:
1. **Clock Skew Tolerant:** Cloudflare edge calculates `liveRemaining = Math.max(0, Math.round((endsAt - now()) / 1000))` and broadcasts it alongside `endsAt`.
2. **Payload Parsing:** `updatedAt` can be either an ISO-8601 string or numeric milliseconds since epoch. `RemoteSession.fromJson` parses both safely.
3. **Local Smooth Ticker:** Between 10-second sync heartbeats, `RemoteSessionService` decrements `remainingSeconds` by 1 every second locally to provide smooth updates without network jitter.
4. **FGS Safety:** On Android 14+, `startForeground` is wrapped in a try-catch block falling back to `NotificationManager.notify()` to guarantee that the notification shade tile is always posted regardless of background execution constraints.
5. **Sub-20ms WebSocket Fanout:** The Cloudflare Durable Object (`SyncRoom`) distributes state packets immediately to connected clients with sub-20ms latency.

---

## 4. Session Takeover & Context Migration (v1.5.1)

When an operator switches devices during a sprint, tapping "Take Over" on the `RemoteSessionPresenceBanner` triggers `TimerCubit.takeOverRemoteSession(session)`:

1. **Duration & Lap Migration:**
   - Adopts `session.remainingSeconds` as local remaining lap duration.
   - Sets total lap duration, lap type (`work`, `shortBreak`, `longBreak`), and lap counter.
2. **Task Context Migration:**
   - Deserializes `session.task` from `session.taskJson` or `session.taskTitle`/`session.taskId`.
   - Persists task to local `Prefs.selectedNotionTask` and updates `TimerState.task`.
   - Local UI updates the task pill and task title immediately.
3. **Activity Tags Migration:**
   - Adopts `session.tags` and matches active tag against local registry by `tagId` or `tagName`.
   - If not in local registry, appends the remote tag dynamically to ensure tag color and icon render properly.
   - Persists tag to local `Prefs.selectedTrackerTagId` and updates `TimerState.tag`.
4. **Displaced Device Protection:**
   - When the taking-over device starts running, it broadcasts its own session with a new `deviceId`.
   - Cloudflare Worker marks the new device as active session owner. Stale stop or pause packets from the displaced device are ignored.

---

## 5. Endpoints & Infrastructure

- **Cloudflare Worker:** `https://pomo-sync.mishra-roshanraj.workers.dev`
- **WebSocket Gateway:** `wss://pomo-sync.mishra-roshanraj.workers.dev/ws`
- **REST Session Check:** `GET https://pomo-sync.mishra-roshanraj.workers.dev/api/session`
- **Fallback Vercel Proxy:** `https://pomo-focus-sand.vercel.app/api/session`
