# Reference: API Endpoints and Payloads

This document defines all external and internal API contracts, WebSocket messages, serverless proxy endpoints, and webhook payload schemas used across Pomo.

---

## 1. Cloudflare Edge Sync Worker (`worker/`)

Base URL: `https://pomo-sync.mishra-roshanraj.workers.dev`  
WebSocket URL: `wss://pomo-sync.mishra-roshanraj.workers.dev/ws`

### `GET /health`

Probes the status of the Cloudflare Worker and its Durable Object state coordinator.

**Headers:** None required.

**Response `200 OK`:**
```json
{
  "status": "healthy",
  "service": "pomo-cloudflare-sync",
  "connections": 2,
  "hasActiveSession": true
}
```

---

### `WS /ws` (WebSocket Gateway)

Establishes a persistent full-duplex WebSocket connection to the Cloudflare Durable Object (`SyncRoom`) for real-time timer state broadcast.

**Connection URL:** `wss://pomo-sync.mishra-roshanraj.workers.dev/ws`  
**Headers (Optional):** `Authorization: Bearer <FOCUS_ACCESS_TOKEN>`

#### Server to Client Messages

1. **Initial State (upon connection):**
   If a session is running:
   ```json
   {
     "type": "SESSION_UPDATE",
     "session": { ... }
   }
   ```
   If no session is running:
   ```json
   {
     "type": "SESSION_IDLE"
   }
   ```

2. **Real-Time Broadcast (`SESSION_UPDATE`):**
   Broadcast to all connected clients whenever any client updates session state (lap start, pause, resume, or finish):
   ```json
   {
     "type": "SESSION_UPDATE",
     "session": {
       "deviceId": "dev_1792561929724_646095",
       "deviceName": "macOS",
       "status": "running",
       "lap": "work",
       "lapNumber": 1,
       "remainingSeconds": 1326,
       "totalSeconds": 1500,
       "tagName": "Deep Work",
       "tagIcon": "⚡",
       "taskTitle": "Documentation architecture",
       "updatedAt": "2026-10-21T11:30:19.395Z",
       "endsAt": "2026-10-21T11:52:25.395Z",
       "liveRemaining": 1326,
       "isRunning": true
     }
   }
   ```

3. **Session Cleared (`SESSION_IDLE`):**
   Broadcast when an active session is reset or stopped:
   ```json
   {
     "type": "SESSION_IDLE"
   }
   ```

4. **Heartbeat Pong:**
   ```json
   {
     "type": "pong"
   }
   ```

#### Client to Server Messages

1. **Publish Session State:**
   ```json
   {
     "type": "SESSION_UPDATE",
     "session": {
       "deviceId": "dev_1792561929724_646095",
       "deviceName": "macOS",
       "status": "running",
       "lap": "work",
       "lapNumber": 1,
       "remainingSeconds": 1500,
       "totalSeconds": 1500,
       "tagName": "Deep Work",
       "tagIcon": "⚡",
       "endsAt": "2026-10-21T11:55:00.000Z"
     }
   }
   ```

2. **Heartbeat Ping:**
   ```json
   {
     "type": "ping"
   }
   ```

---

### `GET /api/session`

HTTP REST endpoint for querying active session state without opening a persistent WebSocket.

**Response `200 OK` (Active Session):**
```json
{
  "active": true,
  "session": {
    "deviceId": "dev_1792561929724_646095",
    "deviceName": "macOS",
    "status": "running",
    "lap": "work",
    "lapNumber": 1,
    "remainingSeconds": 1200,
    "totalSeconds": 1500,
    "tagName": "Deep Work",
    "tagIcon": "⚡",
    "taskTitle": null,
    "updatedAt": "2026-10-21T11:30:19.395Z",
    "endsAt": "2026-10-21T11:50:19.395Z",
    "liveRemaining": 1200,
    "isRunning": true
  }
}
```

**Response `200 OK` (Idle):**
```json
{
  "active": false,
  "session": null
}
```

---

### `POST /api/session`

HTTP REST endpoint for publishing a session update from clients that do not support WebSockets.

**Headers:**
- `Content-Type: application/json`
- `Authorization: Bearer <FOCUS_ACCESS_TOKEN>`

**Request Body:** Complete or partial session object.  
**Response `200 OK`:** Same as `GET /api/session`.

---

## 2. Vercel Serverless Endpoints (`api/`)

Base URL: `https://pomo-focus-sand.vercel.app`

### `ALL /api/notion/v1/*`

Serverless reverse proxy bridging browser PWA clients with the Notion API (`api.notion.com`).

**Authentication Flow:**
1. Browser client sends request with `Authorization: Bearer <FOCUS_ACCESS_TOKEN>`.
2. Vercel proxy validates token against `process.env.FOCUS_ACCESS_TOKEN`.
3. If valid, the proxy rewrites the `Authorization` header to `Bearer <process.env.NOTION_TOKEN>`.
4. Appends `Notion-Version: 2022-06-28`.
5. Forwards the request to `https://api.notion.com/v1/*` and streams back response headers and body with CORS headers (`Access-Control-Allow-Origin: *`).

---

## 3. Webhook Payloads (Home Assistant & Smart Lighting)

Dispatched as HTTP POST requests by `HookHelper` (`lib/helpers/hook_helper.dart`).

**HTTP Method:** `POST`  
**Headers:** `Content-Type: application/json`

**Body:**
```json
{
  "rgb": [255, 0, 156]
}
```

| Field | Type | Description |
|---|---|---|
| `rgb` | `List<int>` | Array of 3 integers `[red, green, blue]` each ranging from `0` to `255`. Matches the active lap color ring. |

**Trigger events:**
- `workStartWebHook`: Fired when a work focus session starts.
- `shortBreakStartWebHook`: Fired when entering a short break.
- `longBreakStartWebHook`: Fired when entering a long break.
- `lapEndWebHook`: Fired when any lap finishes.
- `tickWebHook`: Fired every second during countdowns.
