# How-To: Set Up Cloudflare Edge Sync Worker

This guide explains how to deploy and configure the Cloudflare Edge Worker located in `worker/`. This worker powers Pomo's real-time timer synchronization between macOS, Android, and Web PWA clients using persistent WebSockets and Cloudflare Durable Objects.

---

## 1. Overview and Architecture

Pomo synchronizes active focus sessions across devices with low latency (<20ms at edge) without burdening external databases:

- **Transport**: Persistent WebSocket connections (`/ws`) with automatic reconnect.
- **State Engine**: A Cloudflare Durable Object (`SyncRoom`) keeps the current session in memory and fans out updates immediately to all connected clients.
- **Target Timestamp Model**: Devices broadcast target end timestamps (`endsAt`), allowing the Edge worker and client devices to compute real-time remaining countdowns locally without flooding the network.
- **REST Fallback**: HTTP endpoints (`GET /api/session`, `POST /api/session`) for clients that cannot maintain long-lived WebSockets.

---

## 2. Prerequisites

Before deploying the worker:

- **Node.js**: Node 18+ and `npm`.
- **Cloudflare Account**: A free or paid Cloudflare account (Durable Objects are available on Cloudflare Workers paid plans or via Workers standard).
- **Wrangler CLI**: Install the official Wrangler CLI globally:
  ```bash
  npm install -g wrangler
  ```

---

## 3. Install Dependencies and Authenticate

Navigate to the `worker/` directory and install project dependencies:

```bash
cd worker
npm install
```

Log in to your Cloudflare account with Wrangler:

```bash
wrangler login
```

A browser window will open asking you to authorize Wrangler with your Cloudflare account.

---

## 4. Review `wrangler.toml`

Inspect `worker/wrangler.toml` to ensure the configuration matches your environment:

```toml
name = "pomo-sync"
main = "src/index.js"
compatibility_date = "2024-04-05"
compatibility_flags = ["nodejs_compat"]

[durable_objects]
bindings = [
  { name = "SYNC_ROOM", class_name = "SyncRoom" }
]

[[migrations]]
tag = "v1"
new_classes = ["SyncRoom"]
```

If you wish to change the worker name or deploy to a specific Cloudflare account, adjust `name` or add `account_id` in this file.

---

## 5. Set the Access Token Secret

Pomo authenticates session updates using a shared access token. Set the `FOCUS_ACCESS_TOKEN` secret in Cloudflare:

```bash
wrangler secret put FOCUS_ACCESS_TOKEN
```

When prompted, enter your private access code (the same code you configure in your Pomo app and Vercel settings).

> [!NOTE]
> If `FOCUS_ACCESS_TOKEN` is not set, the worker permits all requests without authentication (convenient for local dev, but not recommended for public production).

---

## 6. Local Testing and Development

Start the local Wrangler development server:

```bash
npm run dev
```

The worker starts at `http://localhost:8787`. You can test endpoints locally:

1. **Health Check**:
   ```bash
   curl http://localhost:8787/health
   ```
   Expected response:
   ```json
   {
     "status": "healthy",
     "service": "pomo-cloudflare-sync",
     "connections": 0,
     "hasActiveSession": false
   }
   ```

2. **WebSocket Connection**:
   You can test WebSocket connectivity using `wscat`:
   ```bash
   npx wscat -c ws://localhost:8787/ws
   ```
   Upon connection, the server immediately replies with:
   ```json
   {"type":"SESSION_IDLE"}
   ```

---

## 7. Deploy to Cloudflare

Deploy your worker to production:

```bash
wrangler deploy
```

Wrangler compiles the worker, creates the Durable Object namespace, applies migrations, and outputs your live deployment URL:

```
Uploaded pomo-sync (1.23 sec)
Deployed pomo-sync triggers (0.54 sec)
  https://pomo-sync.<your-subdomain>.workers.dev
```

---

## 8. (Optional) Custom Domain Configuration

To serve the sync worker under a custom domain (e.g. `sync.yourdomain.com`):

1. Add your domain to Cloudflare DNS.
2. In `worker/wrangler.toml`, uncomment or add the `routes` block:
   ```toml
   routes = [
     { pattern = "sync.yourdomain.com/*", zone_name = "yourdomain.com" }
   ]
   ```
3. Re-run `wrangler deploy`.

---

## 9. Connect Pomo Clients to Your Worker

In `lib/services/remote_session_service.dart`, Pomo defaults to the production endpoint:

```dart
static const String defaultWorkerHost = 'pomo-sync.mishra-roshanraj.workers.dev';
```

If you deployed to your own worker URL or custom domain, update this constant or specify your worker URL in client build definitions.

---

## 10. Verification

To verify full end-to-end multi-device synchronization:

1. Open Pomo on your desktop (macOS).
2. Open Pomo on your phone (Android) or open a Web PWA instance in another browser window.
3. Start a focus sprint on macOS.
4. Within milliseconds:
   - Device B displays a top presence pill banner showing the active session (`Running on macOS`).
   - On Android, the notification shade tile appears with the real-time countdown ticking smoothly every second.
5. Tap **Pause** on macOS: observe that Device B pauses immediately.
6. Tap **Stop** on macOS: observe that Device B clears the active session and hides the presence banner.
