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
    this.tvPairings = new Map();
    this.paraRevision = 0;
    // Durable Objects can be evicted from memory when idle (WebSocket
    // hibernation). Restore the active session so it never "disappears".
    this.state.blockConcurrencyWhile(async () => {
      try {
        const stored = await this.state.storage.get("session");
        if (stored && stored.status !== "stopped") {
          this.session = stored;
        }
      } catch (_) {}
    });
  }

  async persistSession() {
    try {
      if (this.session) {
        await this.state.storage.put("session", this.session);
      } else {
        await this.state.storage.delete("session");
      }
    } catch (_) {}
  }

  async pruneExpiredSession() {
    if (!this.session || this.session.status === "stopped") return null;
    const live = this.calculateLiveSession();
    if (this.session.status === "running" && live.remainingSeconds <= 0) {
      this.session = null;
      await this.persistSession();
      this.broadcast({ type: "SESSION_IDLE" });
      return null;
    }
    return live;
  }

  /**
   * A stop request only clears the active session when it comes from the
   * device that owns it, or from an explicit controller (PARA status page).
   * Idle devices must never wipe another device's timer.
   */
  canStopSession(deviceId, isController) {
    if (isController) return true;
    if (!this.session) return true;
    if (!deviceId) return false;
    return this.session.deviceId === deviceId;
  }

  prunePairings() {
    const now = Date.now();
    for (const [code, entry] of this.tvPairings.entries()) {
      if (now - entry.createdAt > 5 * 60 * 1000) {
        this.tvPairings.delete(code);
      }
    }
  }

  verifyParaSecret(request) {
    const expected = this.env.PARA_SYNC_SECRET;
    if (!expected) return true;
    const authHeader = request.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    return token === expected;
  }

  async fetch(request) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    // Authenticate if FOCUS_ACCESS_TOKEN is configured in environment
    const authHeader = request.headers.get("Authorization") || "";
    const headerToken = authHeader.replace(/^Bearer\s+/i, "").trim();
    const queryToken = (url.searchParams.get("token") || "").trim();
    const token = headerToken || queryToken;
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
      const initialLive = await this.pruneExpiredSession();
      if (initialLive) {
        server.send(JSON.stringify({ type: "SESSION_UPDATE", session: initialLive }));
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
      const live = await this.pruneExpiredSession();
      if (!live) {
        return new Response(JSON.stringify({ active: false, session: null }), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
      return new Response(JSON.stringify({ active: live.isRunning, session: live }), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // REST: POST /api/session
    if (request.method === "POST" && (url.pathname === "/api/session" || url.pathname === "/session")) {
      const body = await request.json();
      return await this.handleSessionUpdate(body);
    }

    // REST: POST /api/para/broadcast - sub-20ms cross-device PARA status invalidation
    if (request.method === "POST" && url.pathname === "/api/para/broadcast") {
      if (!this.verifyParaSecret(request)) {
        return new Response(JSON.stringify({ error: "Unauthorized PARA sync secret" }), {
          status: 401,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
      const body = await request.json().catch(() => ({}));
      this.paraRevision += 1;
      const event = {
        type: "PARA_STATE_PATCH",
        revision: this.paraRevision,
        section: body.section || "all",
        summary: body.summary || null,
        ts: new Date().toISOString(),
      };
      this.broadcast(event);
      return new Response(JSON.stringify({ success: true, revision: this.paraRevision }), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // REST: POST /api/tv-pair/create - Smart TV 4-digit pairing code generation
    if (request.method === "POST" && url.pathname === "/api/tv-pair/create") {
      this.prunePairings();
      let code = String(Math.floor(1000 + Math.random() * 9000));
      for (let i = 0; i < 10 && this.tvPairings.has(code); i++) {
        code = String(Math.floor(1000 + Math.random() * 9000));
      }
      const createdAt = Date.now();
      this.tvPairings.set(code, { code, createdAt, approvedToken: null, approvedBy: null });
      return new Response(
        JSON.stringify({ code, expiresInSeconds: 300, expiresAt: new Date(createdAt + 300000).toISOString() }),
        { headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // REST: GET /api/tv-pair/status?code=XXXX - Smart TV poll + consumption
    if (request.method === "GET" && url.pathname === "/api/tv-pair/status") {
      this.prunePairings();
      const code = (url.searchParams.get("code") || "").trim();
      const entry = this.tvPairings.get(code);
      if (!entry) {
        return new Response(JSON.stringify({ status: "expired" }), {
          status: 404,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
      if (entry.approvedToken) {
        const tok = entry.approvedToken;
        this.tvPairings.delete(code);
        return new Response(JSON.stringify({ status: "approved", tvToken: tok, approvedBy: entry.approvedBy }), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
      return new Response(JSON.stringify({ status: "pending" }), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // REST: POST /api/tv-pair/approve - Authenticated phone approves Smart TV 4-digit code
    if (request.method === "POST" && url.pathname === "/api/tv-pair/approve") {
      if (!this.verifyParaSecret(request)) {
        return new Response(JSON.stringify({ error: "Unauthorized PARA sync secret" }), {
          status: 401,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
      this.prunePairings();
      const body = await request.json().catch(() => ({}));
      const code = String(body.code || "").trim();
      const tvToken = String(body.tvToken || "").trim();
      const approvedBy = String(body.approvedBy || "owner");
      const entry = this.tvPairings.get(code);
      if (!entry || !tvToken) {
        return new Response(JSON.stringify({ error: "Invalid or expired 4-digit TV code" }), {
          status: 404,
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
      entry.approvedToken = tvToken;
      entry.approvedBy = approvedBy;
      this.broadcast({ type: "TV_PAIR_APPROVED", code });
      return new Response(JSON.stringify({ success: true, code }), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // Health check
    if (url.pathname === "/health" || url.pathname === "/") {
      return new Response(
        JSON.stringify({
          status: "healthy",
          service: "pomo-cloudflare-sync",
          version: "1.5.2",
          connections: this.state.getWebSockets().length,
          hasActiveSession: !!(this.session && this.session.status !== "stopped"),
          paraRevision: this.paraRevision,
        }),
        { headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    return new Response("Not found", { status: 404, headers: corsHeaders });
  }

  async handleSessionUpdate(body, senderWs = null) {
    const isController =
      body.isController === true ||
      body.force === true ||
      body.deviceId === "para-status-web";

    // Displaced devices firing a periodic 10s heartbeat must NOT reclaim
    // ownership from the device that just took over.
    if (
      body.isHeartbeat === true &&
      this.session &&
      this.session.status !== "stopped" &&
      body.deviceId &&
      this.session.deviceId !== body.deviceId
    ) {
      const currentLive = await this.pruneExpiredSession();
      if (currentLive) {
        if (senderWs) {
          try {
            senderWs.send(JSON.stringify({ type: "SESSION_UPDATE", session: currentLive }));
          } catch (_) {}
        }
        return new Response(
          JSON.stringify({
            success: true,
            ignored: true,
            displaced: true,
            session: currentLive,
          }),
          { headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }
    }

    if (body.status === "stopped") {
      // Displaced devices sending a stale stopped update must not clear
      // another device's active session, unless this is an explicit controller command.
      if (
        !isController &&
        this.session &&
        body.deviceId &&
        this.session.deviceId !== body.deviceId
      ) {
        return new Response(JSON.stringify({ success: true, ignored: true }), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      const targetDeviceId = this.session?.deviceId || body.deviceId || null;
      this.session = null;
      await this.persistSession();
      this.broadcast({ type: "SESSION_IDLE" });
      this.broadcast({
        type: "SESSION_COMMAND",
        command: "stop",
        targetDeviceId: targetDeviceId,
        by: body.deviceName || body.deviceId || "controller",
      });

      return new Response(JSON.stringify({ success: true, active: false }), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    if (body.status === "resumed" || body.action === "resume") {
      if (this.session) {
        const remainingSecs =
          typeof body.remainingSeconds === "number" && body.remainingSeconds > 0
            ? body.remainingSeconds
            : this.session.remainingSeconds || 1500;
        const now = new Date();
        this.session.status = "running";
        this.session.remainingSeconds = remainingSecs;
        this.session.endsAt = new Date(now.getTime() + remainingSecs * 1000).toISOString();
        this.session.updatedAt = now.toISOString();
        await this.persistSession();

        const live = this.calculateLiveSession();
        this.broadcast({ type: "SESSION_UPDATE", session: live });
        this.broadcast({
          type: "SESSION_COMMAND",
          command: "resume",
          targetDeviceId: this.session.deviceId,
          by: body.deviceName || body.deviceId || "controller",
        });
        return new Response(JSON.stringify({ success: true, session: live }), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }
    }

    if (body.status === "paused") {
      // If another device is actively running, ignore paused reports from displaced devices,
      // unless this is an explicit controller command.
      if (
        !isController &&
        this.session &&
        body.deviceId &&
        this.session.deviceId !== body.deviceId &&
        this.session.status === "running"
      ) {
        return new Response(JSON.stringify({ success: true, ignored: true }), {
          headers: { "Content-Type": "application/json", ...corsHeaders },
        });
      }

      if (this.session) {
        const live = this.calculateLiveSession();
        this.session.status = "paused";
        this.session.remainingSeconds = live.remainingSeconds;
        this.session.endsAt = null;
        this.session.updatedAt = new Date().toISOString();
        await this.persistSession();

        const pausedLive = {
          ...this.session,
          liveRemaining: this.session.remainingSeconds,
          remainingSeconds: this.session.remainingSeconds,
          isRunning: false,
        };
        this.broadcast({ type: "SESSION_UPDATE", session: pausedLive });
        this.broadcast({
          type: "SESSION_COMMAND",
          command: "pause",
          targetDeviceId: this.session.deviceId,
          by: body.deviceName || body.deviceId || "controller",
        });

        return new Response(
          JSON.stringify({ success: true, session: pausedLive }),
          { headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
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
      tagColorHex: body.tagColorHex || null,
      tagId: body.tagId || null,
      tags: Array.isArray(body.tags) ? body.tags : null,
      taskTitle: body.taskTitle || null,
      taskId: body.taskId || null,
      taskJson: body.taskJson || null,
      updatedAt: now.toISOString(),
      endsAt: endsAt,
    };
    await this.persistSession();

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
        await this.handleSessionUpdate(data.payload, ws);
      }
      if (data.type === "SESSION_COMMAND") {
        if (data.command === "stop") {
          const target = this.session?.deviceId || data.targetDeviceId || null;
          this.session = null;
          await this.persistSession();
          this.broadcast({ type: "SESSION_IDLE" });
          this.broadcast({
            type: "SESSION_COMMAND",
            command: "stop",
            targetDeviceId: target,
          });
        } else if (data.command === "pause") {
          if (this.session) {
            const live = this.calculateLiveSession();
            this.session.status = "paused";
            this.session.remainingSeconds = live.remainingSeconds;
            this.session.endsAt = null;
            await this.persistSession();
            const pausedLive = {
              ...this.session,
              liveRemaining: this.session.remainingSeconds,
              remainingSeconds: this.session.remainingSeconds,
              isRunning: false,
            };
            this.broadcast({ type: "SESSION_UPDATE", session: pausedLive });
            this.broadcast({
              type: "SESSION_COMMAND",
              command: "pause",
              targetDeviceId: this.session.deviceId,
            });
          }
        } else if (data.command === "resume") {
          if (this.session) {
            this.session.status = "running";
            this.session.endsAt = new Date(
              Date.now() + (this.session.remainingSeconds || 1500) * 1000
            ).toISOString();
            await this.persistSession();
            const live = this.calculateLiveSession();
            this.broadcast({ type: "SESSION_UPDATE", session: live });
            this.broadcast({
              type: "SESSION_COMMAND",
              command: "resume",
              targetDeviceId: this.session.deviceId,
            });
          }
        }
        return;
      }
      if (data.type === "STOP_SESSION") {
        // Ignore stop requests from devices that do not own the session
        // (e.g. an idle app resetting its own tags/task on startup).
        if (!this.canStopSession(data.deviceId, data.isController === true)) {
          return;
        }
        const target = this.session?.deviceId || data.deviceId || null;
        this.session = null;
        await this.persistSession();
        this.broadcast({ type: "SESSION_IDLE" });
        this.broadcast({
          type: "SESSION_COMMAND",
          command: "stop",
          targetDeviceId: target,
        });
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
      const url = new URL(request.url);
      const roomName = (url.searchParams.get("room") || "global_pomo_sync").slice(0, 64);
      const id = env.SYNC_ROOM.idFromName(roomName);
      const obj = env.SYNC_ROOM.get(id);
      return obj.fetch(request);
    }

    return handleStateless(request, env);
  },
};
