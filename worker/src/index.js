/**
 * Cloudflare Edge Worker for Real-Time Pomo Timer Synchronization
 *
 * Implements the Target Timestamp Model with WebSockets and Cloudflare
 * Durable Objects for sub-20ms multi-device presence fanout.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

/**
 * Durable Object coordinating WebSocket connections and timer state.
 */
export class SyncRoom {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.session = null;
  }

  async fetch(request) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    // Authenticate if FOCUS_ACCESS_TOKEN is configured in environment
    const authHeader = request.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    const expectedToken = this.env.FOCUS_ACCESS_TOKEN;
    if (expectedToken && token !== expectedToken) {
      return new Response(JSON.stringify({ error: "Unauthorized access code" }), {
        status: 401,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // WebSocket upgrade path (/ws or root with Upgrade header)
    const upgradeHeader = request.headers.get("Upgrade");
    if (url.pathname === "/ws" || (upgradeHeader && upgradeHeader.toLowerCase() === "websocket")) {
      if (!upgradeHeader || upgradeHeader.toLowerCase() !== "websocket") {
        return new Response("Expected Upgrade: websocket", { status: 426 });
      }

      const webSocketPair = new WebSocketPair();
      const [client, server] = Object.values(webSocketPair);

      this.state.acceptWebSocket(server);

      // Send initial state immediately upon connection
      if (this.session && this.session.status !== "stopped") {
        const live = this.calculateLiveSession();
        server.send(JSON.stringify({ type: "SESSION_UPDATE", session: live }));
      } else {
        server.send(JSON.stringify({ type: "SESSION_IDLE" }));
      }

      return new Response(null, {
        status: 101,
        webSocket: client,
      });
    }

    // REST: GET /api/session
    if (request.method === "GET" && (url.pathname === "/api/session" || url.pathname === "/session")) {
      if (!this.session || this.session.status === "stopped") {
        return new Response(JSON.stringify({ active: false, session: null }), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
      const live = this.calculateLiveSession();
      return new Response(JSON.stringify({ active: live.isRunning, session: live }), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // REST: POST /api/session
    if (request.method === "POST" && (url.pathname === "/api/session" || url.pathname === "/session")) {
      const body = await request.json();
      return this.handleSessionUpdate(body);
    }

    // Health check
    if (url.pathname === "/health" || url.pathname === "/") {
      return new Response(
        JSON.stringify({
          status: "healthy",
          service: "pomo-cloudflare-sync",
          connections: this.state.getWebSockets().length,
          hasActiveSession: !!(this.session && this.session.status !== "stopped"),
        }),
        { headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    return new Response("Not found", { status: 404, headers: corsHeaders });
  }

  handleSessionUpdate(body) {
    if (body.status === "stopped") {
      // Displaced devices sending a stale stopped update must not clear
      // another device's active session.
      if (this.session && body.deviceId && this.session.deviceId !== body.deviceId) {
        return new Response(JSON.stringify({ success: true, ignored: true }), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
      this.session = null;
      this.broadcast({ type: "SESSION_IDLE" });
      return new Response(JSON.stringify({ success: true, active: false }), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    if (body.status === "paused") {
      // If another device is actively running, ignore paused reports from displaced devices.
      if (
        this.session &&
        body.deviceId &&
        this.session.deviceId !== body.deviceId &&
        this.session.status === "running"
      ) {
        return new Response(JSON.stringify({ success: true, ignored: true }), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
    }

    const now = new Date();
    const remainingSecs =
      typeof body.remainingSeconds === "number" ? body.remainingSeconds : 1500;
    const endsAt =
      body.status === "running"
        ? new Date(now.getTime() + remainingSecs * 1000).toISOString()
        : null;

    this.session = {
      deviceId: body.deviceId || "unknown",
      deviceName: body.deviceName || "Device",
      status: body.status || "running",
      lap: body.lap || "work",
      lapNumber: body.lapNumber || 1,
      remainingSeconds: remainingSecs,
      totalSeconds: body.totalSeconds || remainingSecs,
      tagName: body.tagName || null,
      tagIcon: body.tagIcon || null,
      taskTitle: body.taskTitle || null,
      updatedAt: now.toISOString(),
      endsAt: endsAt,
    };

    const live = this.calculateLiveSession();
    this.broadcast({ type: "SESSION_UPDATE", session: live });

    return new Response(JSON.stringify({ success: true, session: live }), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }

  async webSocketMessage(ws, message) {
    try {
      const data = JSON.parse(message);
      if (data.type === "PING") {
        ws.send(JSON.stringify({ type: "PONG" }));
        return;
      }
      if (data.type === "BROADCAST_SESSION" && data.payload) {
        this.handleSessionUpdate(data.payload);
      }
      if (data.type === "STOP_SESSION") {
        if (
          this.session &&
          data.deviceId &&
          this.session.deviceId !== data.deviceId
        ) {
          return;
        }
        this.session = null;
        this.broadcast({ type: "SESSION_IDLE" }, ws);
      }
    } catch (_) {}
  }

  async webSocketClose(ws, code, reason, wasClean) {
    ws.close(code, "Connection closed");
  }

  broadcast(message, senderWs = null) {
    const payload = JSON.stringify(message);
    const sockets = this.state.getWebSockets();
    for (const ws of sockets) {
      if (ws !== senderWs) {
        try {
          ws.send(payload);
        } catch (_) {}
      }
    }
  }

  calculateLiveSession() {
    if (!this.session) return null;
    const now = Date.now();
    let liveRemaining = this.session.remainingSeconds;
    if (this.session.status === "running" && this.session.endsAt) {
      const endsAtMs = new Date(this.session.endsAt).getTime();
      liveRemaining = Math.max(0, Math.round((endsAtMs - now) / 1000));
    }
    return {
      ...this.session,
      liveRemaining,
      remainingSeconds: liveRemaining,
      isRunning: this.session.status === "running" && liveRemaining > 0,
    };
  }
}

// In-memory fallback if running without Durable Objects binding
let fallbackSession = null;

function handleStateless(request, env) {
  const url = new URL(request.url);

  if (request.method === "GET" && (url.pathname === "/api/session" || url.pathname === "/session")) {
    if (!fallbackSession || fallbackSession.status === "stopped") {
      return new Response(JSON.stringify({ active: false, session: null }), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }
    const now = Date.now();
    let liveRemaining = fallbackSession.remainingSeconds;
    if (fallbackSession.status === "running" && fallbackSession.endsAt) {
      liveRemaining = Math.max(
        0,
        Math.round((new Date(fallbackSession.endsAt).getTime() - now) / 1000)
      );
    }
    const live = {
      ...fallbackSession,
      liveRemaining,
      remainingSeconds: liveRemaining,
      isRunning: fallbackSession.status === "running" && liveRemaining > 0,
    };
    return new Response(JSON.stringify({ active: live.isRunning, session: live }), {
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }

  return new Response("Cloudflare Sync Worker Active", {
    headers: { "Content-Type": "text/plain", ...corsHeaders },
  });
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    if (env.SYNC_ROOM) {
      const id = env.SYNC_ROOM.idFromName("global_pomo_sync");
      const obj = env.SYNC_ROOM.get(id);
      return obj.fetch(request);
    }

    return handleStateless(request, env);
  },
};
