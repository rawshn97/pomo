# Pomo Cloudflare Sync Worker

Low-latency Cloudflare Edge Worker for real-time Pomodoro timer synchronization across macOS, Android, and Web PWA.

## Architecture

- **Transport:** Persistent WebSockets with Cloudflare Durable Objects.
- **Protocol:** Target Timestamp Model (`endsAt - now()`) with instant event-driven fanout (<20ms edge latency).
- **Fallback:** Standard HTTP REST endpoints (`GET /api/session`, `POST /api/session`) matching the Vercel relay.

## Deploying to Cloudflare

1. Ensure Wrangler CLI is installed (installed globally via `npm install -g wrangler`).
2. Login to your Cloudflare account:
   ```bash
   wrangler login
   ```
3. Set your secret access token (matching your Notion/Focus access code):
   ```bash
   cd worker
   wrangler secret put FOCUS_ACCESS_TOKEN
   ```
4. Deploy the worker:
   ```bash
   wrangler deploy
   ```
5. (Optional) Map to custom domain `sync.rawshn.com`:
   In `worker/wrangler.toml`, uncomment:
   ```toml
   routes = [
     { pattern = "sync.rawshn.com/*", zone_name = "rawshn.com" }
   ]
   ```
   and redeploy with `wrangler deploy`.

## Local Development & Testing

```bash
cd worker
npm run dev
```

Visit `http://localhost:8787/health` or connect a WebSocket to `ws://localhost:8787/ws`.
