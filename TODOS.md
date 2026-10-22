# TODOS

## Upcoming Sprint Backlog
- [ ] **Decommission Android exact hourly check-in alarms:** Cancel alarms on launch in `MainActivity.kt`, decommission `HourlyAlarmScheduler`, remove `BootReceiver` alarm rescheduling and `HourlyAlarmReceiver` re-arming loop, and clean up arb strings. (SPEC_IN_PROGRESS Section 1)
- [ ] **Manual time logging overlap detection & resolution:** Show visual overlap warning banner in `ManualTimeEntryDialog` and implement Equal-Split Merge algorithm to prevent double-counting across the 60m clock hour. (SPEC_IN_PROGRESS Section 3)
- [ ] **Augmented PARA focus target selector:** Multi-tier drilldown modal supporting Area/Resource -> Project -> Task selection on the Focus Timer. (SPEC_IN_PROGRESS Section 2)

## Future Architecture Scalability Backlog
- [ ] **Migrate `Prefs.pendingTimeLogs` to `sqflite`:** If offline time log accumulation in `SharedPreferences` exceeds 1,000 pending entries per month during prolonged off-grid usage, migrate the JSON list queue to an indexed local `sqflite` database table (`time_blocks`).

## Closed
- [x] **Real-time active task and activity tags migration during cross-device session takeover:** Seamless context handover across phone, macOS, and web PWA shipped in v1.5.1 (specs/remote-sync.md).
- [x] **Android Material 3 adaptive icon with Rawshn brand identity:** Obsidian #0A0C10, cyan #00F0FF, magenta #FF00AA, monochrome themed icon, and splash assets shipped in v1.5.0.
- [x] **Cloudflare Edge Worker sync relay with Durable Objects WebSocket sub-20ms broadcast:** Hosted at pomo-sync.mishra-roshanraj.workers.dev with in-memory session persistence shipped in v1.4.6 to v1.4.8 (specs/remote-sync.md).
- [x] **Real-time cross-device timer sync via Cloudflare Worker WebSockets:** Target Timestamp model, 1s local notification shade ticker on Android, and WebSocket relay shipped in v1.4.7 (specs/remote-sync.md).
- [x] **Android in-app OTA APK updater:** AppUpdateService with automated GitHub Releases manifest checking shipped in v1.4.5.
- [x] **Wire battery optimization request in Settings:** `AndroidBatteryOptTile` + MethodChannel (`requestIgnoreBatteryOptimizations`) shipped (A2). Tracker also prompts on enable (A8). Overnight Doze / OEM remains residual device QA, not a missing Settings affordance.
