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
  a.room.handleSessionUpdate({
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
  room.handleSessionUpdate({ deviceId: "para-status-web", status: "running", remainingSeconds: 600, force: true });
  await room.webSocketMessage({}, JSON.stringify({ type: "STOP_SESSION", deviceId: "idle-phone" }));
  assert.equal(room.session.deviceId, "para-status-web");
});

test("owner and controller STOP_SESSION clear the session", async () => {
  const { room } = makeRoom();
  room.handleSessionUpdate({ deviceId: "mac", status: "running", remainingSeconds: 600 });
  await room.webSocketMessage({}, JSON.stringify({ type: "STOP_SESSION", deviceId: "mac" }));
  assert.equal(room.session, null);
  room.handleSessionUpdate({ deviceId: "mac", status: "running", remainingSeconds: 600 });
  await room.webSocketMessage({}, JSON.stringify({ type: "STOP_SESSION", deviceId: "x", isController: true }));
  assert.equal(room.session, null);
});

test("takeover: new device replaces session and everyone is notified", async () => {
  const { room, sent } = makeRoom();
  room.handleSessionUpdate({ deviceId: "para-status-web", status: "running", remainingSeconds: 600, force: true });
  room.handleSessionUpdate({ deviceId: "mac", status: "running", remainingSeconds: 590, tagName: "Deep Work" });
  assert.equal(room.session.deviceId, "mac");
  const last = sent.filter((m) => m.type === "SESSION_UPDATE").pop();
  assert.equal(last.session.deviceId, "mac");
});
