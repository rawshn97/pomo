# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.2] - 2026-10-28

### Added
- Seamless cross-surface `Take Over` across macOS (app window + menu bar item), Android APK, Web PWA (`/focus`), and PARA Status (`/status`).
- Sprint duration adoption (`15m`, `25m`, `50m`, or custom `1..60m`) during remote session takeover so adopted sprints preserve exact total and remaining time.
- Automatic 25-second WebSocket `PING` keepalive and 3.5-second auto-reconnect in `RemoteSessionService`.

### Fixed
- Persisted active focus session in Cloudflare Durable Object transactional storage (`SyncRoom`) so WebSocket Hibernation (~10s idle eviction) never drops timers started from `/status` or remote surfaces.
- Prevented post-takeover reset race (`beginLocalTakeover` grace window), stale 10-second heartbeat ownership clobbering (`isHeartbeat` check), non-owner stop clearing, and zero-minute orphan Notion time stubs on displaced devices.
- Updated default Cloudflare sync endpoint to `https://sync.rawshn.com/api/session`.

## [1.5.1] - 2026-10-22

### Added
- Real-time active task and activity tags migration during cross-device session takeover between phone, macOS, and web PWA.
- Extended `RemoteSession` model with `NotionTask` reconstruction and structured `tags` list parsing.
- Immediate UI updates on the local Timer tab upon takeover: automatically populates task label, Notion task metadata, and tracker tag selection without manual re-entry.
- Cloudflare Edge Worker and REST endpoint support for `task`, `taskJson`, and `tags` session attributes.

## [1.5.0] - 2026-10-22

### Added
- Android Material 3 adaptive icon with Rawshn brand identity (obsidian `#0A0C10`, cyan `#00F0FF`, magenta `#FF00AA`).
- Android 13+ dynamic theming with monochrome themed icon (`ic_launcher_monochrome.png`).
- Multi-density launcher assets across `mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, and `xxxhdpi`.
- Obsidian dark glass splash screen assets and vector SVG artwork.
- Multi-resolution macOS AppIcon, Windows icon (`.ico`), and Web PWA maskable icons (`192x192`, `512x512`).

## [1.4.9] - 2026-10-22

### Fixed
- Resolved remote session takeover reset bug and enabled seamless bidirectional handover between devices.
- Guarded Cloudflare Worker session state so displaced devices sending stale `stopped` or `paused` updates do not cancel active sessions taken over by another device.

## [1.4.8] - 2026-10-22

### Added
- Omnidirectional cross-device sync: any timer running on macOS, Android, or PWA seamlessly synchronizes with the other two platforms in real time.
- macOS menu bar remote sync: when local timer is idle on Mac, the menu bar status item displays the live remote countdown (e.g. mobile or web) with tooltip and status.
- PWA dynamic tab title: browser tab title dynamically reflects active countdowns for both local sessions (`(24:15) Focus`) and remote sessions (`(24:15 - macOS) Focus`).
- Session takeover: presence banner on Timer tab includes a "Take Over" button to immediately adopt remote activity tags and resume tracking on the local device.
- Paused state indication: presence banner gracefully presents paused remote sessions in amber without disappearing or dropping state.

### Fixed
- Fixed 1-second network broadcast spam by decoupling local tick listeners from network broadcast triggers, replacing per-second re-broadcasts with state transition triggers and 10-second heartbeats.
- Distinguish Web device icons (`Icons.language`) in remote presence banner alongside Mobile and macOS.

## [1.4.7] - 2026-10-21

### Fixed
- Fixed runtime `TypeError` in `RemoteSession.fromJson` caused by casting Cloudflare ISO-8601 timestamp strings as `num`. Deserializer now supports both ISO-8601 strings and millisecond epochs safely.
- Added smooth 1-second countdown ticker in `RemoteSessionService` so the Android notification shade counts down every second in lockstep with the running macOS timer.
- Added crash safety guard and direct `NotificationManager.notify()` fallback to `TimerForegroundService.kt` for Android 14+ background execution policies.

## [1.4.6] - 2026-10-21

### Added
- Real-time cross-device timer synchronization via Cloudflare Edge Worker WebSocket relay (`pomo-sync.mishra-roshanraj.workers.dev`).
- Active macOS focus sessions automatically mirror to the Android notification shade and Timer tab presence banner.
- Target Timestamp model computing edge countdown dynamically without streaming every second over the network.
- Allowed remote session sync without requiring Notion API key configuration.

## [1.4.5] - 2026-10-21

### Added
- In-app over-the-air (OTA) updater for Android release APKs (`AppUpdateService`).
- Equal-split merge calculation for hourly logs to prevent double-counting when time blocks overlap.

## [1.4.0] - 2026-10-20

### Added
- Visual brand alignment with rawshn.com design system (dark glass / neon).
- Manual time log entry and history editing in the Tracker tab.
- Week-to-date and custom date filters for hourly time tracking.
- Decommissioned desktop hourly check-in reminder banners on macOS.
