// Run with: node --test worker/test/sync-room.test.mjs
import test from "node:test";
import assert from "node:assert/strict";
import { SyncRoom } from "../src/index.js";

function makeRoom(initial = {}) {
  const store = new Map(Object.entries(initial));
  const sockets = [];
  const state = {
    storage: {
      get: async (k) => store.get(k),
      put: async (k, v) => void store.set(k, v),
      delete: async (k) => void store.delete(k),
    },
    blockConcurrencyWhile: async (fn) => fn(),
    getWebSockets: () => sockets,
    acceptWebSocket: () => {},
  };
  const room = new SyncRoom(state, {});
  const sent = [];
  sockets.push({ send: (m) => sent.push(JSON.parse(m)) });
  return { room, store, sent };
}

const tick = () => new Promise((r) => setTimeout(r, 5));

test("session survives Durable Object eviction (persisted + restored)", async () => {
  const a = makeRoom();
  await a.room.handleSessionUpdate({
    deviceId: "para-status-web", status: "running", remainingSeconds: 600, totalSeconds: 1500, force: true,
  });
  await tick();
  assert.ok(a.store.get("session"));
  const b = makeRoom({ session: a.store.get("session") });
  await tick();
  assert.equal(b.room.session.deviceId, "para-status-web");
});

test("idle device STOP_SESSION does not wipe another device's timer", async () => {
  const { room } = makeRoom();
  await room.handleSessionUpdate({ deviceId: "para-status-web", status: "running", remainingSeconds: 600, force: true });
  await room.webSocketMessage({}, JSON.stringify({ type: "STOP_SESSION", deviceId: "idle-phone" }));
  assert.equal(room.session.deviceId, "para-status-web");
});

test("owner and controller STOP_SESSION clear the session", async () => {
  const { room } = makeRoom();
  await room.handleSessionUpdate({ deviceId: "mac", status: "running", remainingSeconds: 600 });
  await room.webSocketMessage({}, JSON.stringify({ type: "STOP_SESSION", deviceId: "mac" }));
  assert.equal(room.session, null);
  await room.handleSessionUpdate({ deviceId: "mac", status: "running", remainingSeconds: 600 });
  await room.webSocketMessage({}, JSON.stringify({ type: "STOP_SESSION", deviceId: "x", isController: true }));
  assert.equal(room.session, null);
});

test("takeover: new device replaces session and stale 10s heartbeat from displaced device is rejected", async () => {
  const { room, sent } = makeRoom();
  await room.handleSessionUpdate({ deviceId: "mac", status: "running", remainingSeconds: 600, totalSeconds: 1500 });
  await room.handleSessionUpdate({ deviceId: "android", status: "running", remainingSeconds: 590, totalSeconds: 1500, tagName: "Deep Work" });
  assert.equal(room.session.deviceId, "android");

  // Displaced mac fires a stale 10s heartbeat; must NOT overwrite android's session!
  const res = await room.handleSessionUpdate({
    deviceId: "mac",
    status: "running",
    remainingSeconds: 580,
    isHeartbeat: true,
  });
  const data = await res.json();
  assert.equal(data.displaced, true);
  assert.equal(room.session.deviceId, "android");
  const last = sent.filter((m) => m.type === "SESSION_UPDATE").pop();
  assert.equal(last.session.deviceId, "android");
});

test("controller resume preserves original owning deviceId", async () => {
  const { room } = makeRoom();
  await room.handleSessionUpdate({ deviceId: "mac", deviceName: "macOS", status: "running", remainingSeconds: 900, totalSeconds: 1500 });
  await room.handleSessionUpdate({ deviceId: "para-status-web", status: "paused", force: true });
  assert.equal(room.session.status, "paused");
  assert.equal(room.session.deviceId, "mac");

  await room.handleSessionUpdate({ deviceId: "para-status-web", status: "resumed", force: true });
  assert.equal(room.session.status, "running");
  assert.equal(room.session.deviceId, "mac");
});

test("expired running session is automatically cleared on GET /api/session", async () => {
  const { room, store } = makeRoom();
  room.session = {
    deviceId: "para-status-web",
    deviceName: "PARA Status",
    status: "running",
    remainingSeconds: 5,
    totalSeconds: 1500,
    endsAt: new Date(Date.now() - 5000).toISOString(),
  };
  await room.persistSession();
  const res = await room.fetch(new Request("https://sync.rawshn.com/api/session"));
  const body = await res.json();
  assert.equal(body.active, false);
  assert.equal(body.session, null);
  assert.equal(store.get("session"), undefined);
});
