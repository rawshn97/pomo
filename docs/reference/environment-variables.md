# Reference: Environment Variables and Configuration

This reference document details all environment variables, compile-time Dart defines, secret keys, and local configuration files used across Pomo.

---

## 1. Compile-Time Dart Defines (`--dart-define`)

Dart defines are passed to `flutter run` or `flutter build` to configure endpoints and behaviors at build time:

| Define Flag | Default Value | Description |
|---|---|---|
| `UPDATE_MANIFEST_URL` | `https://pomo-focus-sand.vercel.app/android/version.json` | URL checked by Android `AppUpdateService` to detect newer APK releases. |
| `REMOTE_SYNC_WS_URL` | `wss://pomo-sync.mishra-roshanraj.workers.dev/ws` | WebSocket endpoint for real-time timer sync relay. |
| `REMOTE_SYNC_HTTP_URL` | `https://pomo-sync.mishra-roshanraj.workers.dev/api/session` | HTTP REST endpoint for remote session polling fallback. |
| `FOCUS_ACCESS_TOKEN` | (Empty / Prompted) | Optional access code baked into private builds for automatic proxy authentication. |

Example usage:
```bash
flutter build apk --flavor production -t lib/main_production.dart \
  --dart-define=UPDATE_MANIFEST_URL="https://example.com/android/version.json"
```

---

## 2. Vercel Serverless Environment Variables

Configured in the Vercel project dashboard for the web proxy (`api/notion.js` and `api/session.js`):

| Variable | Required | Description |
|---|---|---|
| `NOTION_TOKEN` | Yes (for Notion proxy) | Notion internal integration secret (`secret_...` or `ntn_...`). Injected server-side by `/api/notion/*` when communicating with `api.notion.com`. |
| `FOCUS_ACCESS_TOKEN` | Yes (for protected proxy) | Shared passphrase required in the `Authorization: Bearer <token>` header from web browser sessions. |

---

## 3. Cloudflare Worker Secrets

Configured in Cloudflare via `wrangler secret put` inside the `worker/` directory:

| Secret | Required | Description |
|---|---|---|
| `FOCUS_ACCESS_TOKEN` | Recommended | Shared access token required to publish session updates to `/ws` or `/api/session`. If unset, the worker accepts unauthenticated session writes. |

Setting a secret:
```bash
cd worker
wrangler secret put FOCUS_ACCESS_TOKEN
```

---

## 4. Android Signing Configuration (`android/key.properties`)

Required for production APK builds (`scripts/build_android_release_apk.sh`). This file is untracked by Git:

```properties
storePassword=KEYSTORE_PASSWORD
keyPassword=KEY_PASSWORD
keyAlias=pomo
storeFile=/path/to/pomo-release.jks
```

| Property | Description |
|---|---|
| `storePassword` | Master password for the release keystore file. |
| `keyPassword` | Password for the specific key alias inside the keystore. |
| `keyAlias` | Name of the key entry in the keystore (default: `pomo`). |
| `storeFile` | Absolute filesystem path to `pomo-release.jks`. |

---

## 5. Local Environment Files

| File | Tracked | Purpose |
|---|---|---|
| `sample.env` | Yes | Documents required tooling versions (`FLUTTER_VERSION=3.19.6`, `JAVA_VERSION=17`). |
| `.env.local` | No | Local developer overrides for testing. |
| `.env.production.local` | No | Local overrides for production staging. |

---

## 6. SharedPreferences Storage Keys (`Prefs`)

Pomo persists runtime preferences locally on each device via `Prefs` (`lib/singletons/prefs.dart`):

| Key | Type | Description |
|---|---|---|
| `work_minutes` | `int` | Duration of work lap in minutes (default: `25`). |
| `short_break_minutes` | `int` | Duration of short break in minutes (default: `5`). |
| `long_break_minutes` | `int` | Duration of long break in minutes (default: `15`). |
| `lap_count` | `int` | Number of work laps before a long break (default: `4`). |
| `enable_sound` | `bool` | Whether audio chimes play on lap transitions. |
| `theme_mode` | `String` | Theme mode (`system`, `light`, `dark`). |
| `color_seed` | `int` | 32-bit ARGB seed color for Material 3 dynamic color scheme. |
| `notion_enabled` | `bool` | Toggle for Notion two-way sync. |
| `notion_api_key` | `String` | Saved Notion integration token. |
| `notion_time_logs_db_id` | `String` | 32-char hex ID for Time Logs database. |
| `notion_hourly_timeline_db_id` | `String` | 32-char hex ID for Hourly Timeline database. |
| `activity_tags` | `String` | Serialized JSON list of custom activity tags (name, icon, color). |
| `deleted_activity_tags` | `List<String>` | Tombstone list of deleted tag names to prevent resurrecting during sync. |
| `pending_hourly_notion_logs` | `String` | Serialized JSON queue of un-flushed offline logs. |
| `quiet_hours_enabled` | `bool` | Whether quiet hours suppression is active. |
| `quiet_hours_start` | `int` | Hour slot when quiet hours start (`0` to `23`). |
| `quiet_hours_end` | `int` | Hour slot when quiet hours end (`0` to `23`). |
| `web_hooks_enabled` | `bool` | Whether external RGB HTTP webhooks are dispatched. |
| `web_hook_work_start` | `String` | Comma-separated URLs triggered on work lap start. |
| `web_hook_tick` | `String` | Comma-separated URLs triggered every second on timer tick. |
