# Remote Session & Real-Time Sync Specification

**Spec file:** `specs/remote-sync.md`  
**Parent index:** [`SPEC.md`](../SPEC.md)  
**Shipped in:** `v1.4.6` (initial WebSocket relay), `v1.4.7` (payload deserialization fix + 1-second local notification tick), `v1.4.8` (omnidirectional 3-way sync, macOS menu bar sync, PWA dynamic title, session takeover, and 10s heartbeat throttling)  
**Related files:**
- `worker/src/index.js` (Cloudflare Worker + Durable Objects WebSocket relay)
- `worker/wrangler.toml` (Cloudflare Worker configuration)
- `lib/models/remote_session.dart` (Data model with Target Timestamp parsing)
- `lib/services/remote_session_service.dart` (WebSocket client, REST polling fallback, local 1-second countdown ticker)
- `lib/widgets/remote_session_presence_banner.dart` (Timer tab remote session presence pill)
- `android/app/src/main/kotlin/com/recoskyler/pomo/TimerForegroundService.kt` (Android notification shade sync)

---

## 1. Problem Statement

When a focus session runs on a desktop device (macOS menu bar or window), the user needs their mobile phone (Android) to reflect the active countdown immediately in the Android notification shade and in the app UI, without manually starting a duplicate timer or polling Notion databases.

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
|                      macOS Client                         |
|  - TimerCubit runs focus session                          |
|  - Posts heartbeat & state transitions to Cloudflare WS   |
+-----------------------------+-----------------------------+
                              |
                              | WSS / HTTPS
                              v
+-----------------------------------------------------------+
|       Cloudflare Edge Worker (pomo-sync)                  |
|  - URL: https://pomo-sync.mishra-roshanraj.workers.dev    |
|  - WebSocket: wss://.../ws                                |
|  - Durable Object: SyncRoom                               |
|  - Computes: liveRemaining = max(0, endsAt - now())       |
|  - Broadcasts to all connected peer clients               |
+-----------------------------+-----------------------------+
                              |
                              | Push over WebSocket
                              v
+-----------------------------------------------------------+
|                     Android Client                        |
|  - RemoteSessionService receives session packet           |
|  - Starts local 1s countdown ticker (_startRemoteTick)    |
|  - Updates TimerForegroundService notification shade      |
|  - Displays RemoteSessionPresenceBanner on Timer tab      |
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
  "tagName": "Socializing",
  "tagIcon": "🍷",
  "taskTitle": null,
  "updatedAt": "2026-10-21T11:30:19.395Z",
  "endsAt": "2026-10-21T11:52:25.395Z",
  "liveRemaining": 1326,
  "isRunning": true
}
```

### Invariants:
1. **Clock Skew Tolerant:** Cloudflare edge calculates `liveRemaining = Math.max(0, Math.round((endsAt - now()) / 1000))` and broadcasts it alongside `endsAt`.
2. **Payload Parsing:** `updatedAt` can be either an ISO-8601 string or numeric milliseconds since epoch. `RemoteSession.fromJson` parses both safely.
3. **Local Smooth Ticker:** Between 10-second sync packets, `RemoteSessionService` decrements `remainingSeconds` by 1 every second locally to provide smooth shade updates without jitter.
4. **FGS Safety:** On Android 14+, `startForeground` is wrapped in a try-catch block falling back to `NotificationManager.notify()` to guarantee that the notification shade tile is always posted regardless of background execution constraints.

---

## 4. Endpoints & Infrastructure

- **Cloudflare Worker:** `https://pomo-sync.mishra-roshanraj.workers.dev`
- **WebSocket Gateway:** `wss://pomo-sync.mishra-roshanraj.workers.dev/ws`
- **REST Session Check:** `GET https://pomo-sync.mishra-roshanraj.workers.dev/api/session`
- **Fallback Vercel Proxy:** `https://pomo-focus-sand.vercel.app/api/session`
