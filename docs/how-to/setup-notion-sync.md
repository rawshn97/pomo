# How-To: Set Up Notion Sync

This guide details how to integrate Pomo with your Notion workspace. Once connected, your Pomodoro focus sessions automatically log to your Notion **Time Logs** database, and your 24-hour activity grid syncs to your **Hourly Timeline** database.

---

## 1. Create a Notion Internal Integration

1. Navigate to [Notion Developers: My Integrations](https://www.notion.so/my-integrations).
2. Click **+ New integration**.
3. Fill in the integration details:
   - **Name**: `Pomo Sync`
   - **Associated workspace**: Select your active personal or team workspace.
   - **Type**: Internal.
4. Under **Capabilities**, ensure the following permissions are granted:
   - Read content
   - Update content
   - Insert content
5. Click **Save** and copy the **Internal Integration Secret** (starts with `secret_` or `ntn_`). Keep this secret safe.

---

## 2. Set Up Notion Databases

You need two Notion databases in your workspace. You can create new databases or connect existing databases that share these properties.

### Database A: Time Logs (Pomodoro Sessions)

Create a full-page database named `Time Logs` and configure the following properties:

| Property Name | Property Type | Description |
|---|---|---|
| `Task` | Title | Focus sprint name or active task title |
| `Date` | Date | Start timestamp and end timestamp of the lap |
| `Minutes` | Number | Elapsed duration in minutes |
| `Lap` | Select | Lap type (`Work`, `Short Break`, `Long Break`) |
| `Tags` | Multi-select | Associated activity tags (e.g. `Deep Work`, `Writing`) |

### Database B: Hourly Timeline (24h Activity Tracker)

Create a full-page database named `Hourly Timeline` and configure the following properties:

| Property Name | Property Type | Description |
|---|---|---|
| `Hour` | Title | Hour slot label (e.g. `Hour 14:00 - 15:00`) |
| `Date` | Date | Exact calendar day for the hourly slot |
| `Tags` | Rich text | Multi-tag allocations or activity breakdown |
| `Notes` | Rich text | Notes logged for this hour block |
| `Source` | Select | Identifier: `pomo` for hours, `pomo-activity-tag` for custom tags |

---

## 3. Share Databases with the Integration

By default, Notion integrations cannot access any pages or databases until explicitly invited:

1. Open your **Time Logs** database page in Notion.
2. Click the `...` menu in the top right corner.
3. Scroll down to **Connections** and click **Connect to**.
4. Search for `Pomo Sync` and confirm access.
5. Repeat these steps for your **Hourly Timeline** database page.

---

## 4. Extract Database IDs

Copy the 32-character database ID from each database page URL:

```
https://www.notion.so/myworkspace/a8b2c3d4e5f67890123456789abcdef0?v=...
                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                           Database ID
```

The database ID is the 32-character hexadecimal string between the slash after your workspace name and the question mark (`?v=`).

---

## 5. Configure Pomo Settings

### Native macOS and Android Builds

On native desktop and mobile platforms, Pomo connects directly to the official Notion API (`https://api.notion.com/v1/`):

1. Open Pomo and navigate to the **Settings** tab.
2. Scroll to the **Notion Sync** section.
3. Toggle **Enable Notion Sync** to **ON**.
4. Enter your credentials:
   - **Notion Integration Token**: Paste your `secret_...` or `ntn_...` token.
   - **Time Logs Database ID**: Paste the 32-character hex ID for Time Logs.
   - **Hourly Timeline Database ID**: Paste the 32-character hex ID for Hourly Timeline.
5. Tap **Test Connection** or navigate to the Tracker tab to trigger an initial sync.

### Web PWA (Browser CORS Proxy)

Web browsers block direct HTTP requests from web applications to `api.notion.com` due to Cross-Origin Resource Sharing (CORS) security restrictions.

To use Notion sync in the Web PWA:

1. Deploy the included Vercel serverless proxy (see [How-To: Release and Deploy](release-and-deploy.md)).
2. Set the following environment variables in your Vercel project:
   - `NOTION_TOKEN`: Your Notion integration secret (`secret_...`).
   - `FOCUS_ACCESS_TOKEN`: A private passphrase you choose.
3. In the Web PWA Settings, toggle **Enable Notion Sync** and enter your `FOCUS_ACCESS_TOKEN` when prompted. The web client routes calls to `/api/notion/v1/`, which validates your access token and injects the real Notion token server-side.

---

## 6. Activity Tag Registry and Synchronization

Custom activity tags defined in Pomo (with custom names, emoji icons, and colors) sync bidirectionally:

- **Local to Notion**: When you create or update an activity tag in Pomo, `TagRegistryWriter` writes an entry to your Hourly Timeline database with `Source = pomo-activity-tag`.
- **Notion to Local**: On startup and sync cycles, Pomo reads tags with `Source = pomo-activity-tag` to ensure all your devices stay consistent.
- **Deletions**: Deleting a tag in Pomo records a local tombstone in `Prefs.deletedActivityTags`. This prevents background sync from re-importing tags you intentionally removed.

---

## 7. Offline Resilience and Error Handling

Pomo is designed for offline-first usage:

- If you log hours or complete focus laps while disconnected from the internet, Pomo queues them in local JSON storage (`Prefs.pendingHourlyNotionLogs`).
- When network connectivity returns, `NotionSyncService.flushPendingHourlyLogs()` flushes queued entries to Notion automatically.
- If a Notion API rate limit (HTTP 429) is hit, Pomo uses exponential backoff and retries without dropping local state.

---

## 8. Verification

To verify that your integration is working properly:

1. On the **Hourly Tracker** tab, tap any hour slot and log an activity tag (e.g. `Deep Work`).
2. Open your **Hourly Timeline** database in Notion: confirm a new row appears with the corresponding hour and date.
3. On the **Timer** tab, run a quick sprint (or set Work Duration to 1 minute in Settings for testing) and let it complete.
4. Open your **Time Logs** database in Notion: confirm a new row records the completed session.
