# AGENTS.md - Pomo

Operating rules for AI agents in `pomo` (`github.com/rawshn97/pomo`, forked from `recoskyler/pomo`).

**Sources of truth:** this file = agent operating rules; `SPEC.md` + `specs/` = shipped product contracts; `CLAUDE.md` = topology & build; `ARCHITECTURE.md` = system design; `DESIGN.md` = original product design (2026-07-13). Cursor always-on: `.cursor/rules/agent-guidance.mdc`.

## Product / purpose

Cross-platform Flutter Pomodoro + time tracker: work/break laps, sounds, RGB webhooks (HomeAssistant), Notion activity tags/sync, multi-window desktop / macOS menu bar, Android background ticks.

## Layout

| Path | Role |
|------|------|
| `lib/main_*.dart` | Flavor entry points (`development` / `staging` / `production`); `main.dart` is a stub |
| `lib/app/` | Root `App` / `AppView`, `MultiBlocProvider` |
| `lib/pages/` | Features: `timer`, `tracker`, `settings`, `tasks`, `about`, … |
| `lib/helpers/` | Pure logic (`DurationHelper`, `LapHelper`, `HookHelper`, …) |
| `lib/services/` | Platform / background (`TimerTickService`, notifications, …) |
| `lib/desktop/` | Multi-window shell, overlay, macOS menu bar |
| `lib/singletons/` | `Prefs` and shared singletons |
| `scripts/` | `setup.sh`, `verify.sh`, `build-web.sh`, … |
| `SPEC.md` / `specs/` | Shipped product specs (index + per feature) |
| `SPEC_IN_PROGRESS.md` | Unshipped / agreed-not-built work |
| `docs/superpowers/` | Process rails, gap matrix, dated plans, QA |
| `DESIGN.md` / `TODOS.md` | Original design SoT / scalability backlog |

## Commands

```bash
./scripts/setup.sh
# or: flutter pub get && flutter gen-l10n

flutter run --flavor development -d macos --target lib/main_development.dart
./scripts/verify.sh
# inspect with rtk: rtk git status | rtk git diff | rtk grep "TimerCubit"
```

## Hard constraints

1. Always `--flavor` + `--target`; never treat `lib/main.dart` as the real entry.
2. Run `flutter pub get` + `flutter gen-l10n` (or `./scripts/setup.sh`) before analyze/test/build.
3. Prefix inspection shells with `rtk` where applicable.
4. No em dash (`U+2014`) in docs, comments, commits, or UI strings; use `-`, `:`, or `;`.
5. Keep helpers in `lib/helpers/` free of `BuildContext`; immutable Cubit states via `copyWith`.
6. Do not invent remotes, force-push, or commit unless the user asks.

## Agent workflow

1. Read this file + `README.md` + `SPEC.md`; for architecture also `CLAUDE.md`, `ARCHITECTURE.md`.
2. Change one feature → edit that file under `specs/`. Unshipped ideas → `SPEC_IN_PROGRESS.md`.
3. Check `docs/superpowers/DESIGN-GAP-MATRIX.md` before scoping product work.
4. Process path: brainstorming → writing-plans → TDD → implement → `./scripts/verify.sh` → review/ship as needed.

## Secrets / local-only

- Never commit `.env`, `.env.*` (see `.gitignore`). Template: tracked `sample.env` (not `.env.example`).
- Do not commit credentials, personal Notion tokens, or local session dumps.
- Never commit `android/key.properties` or `*.jks`.

### Android release keystore (agent recovery)

If a production APK build fails for missing signing config and no local `android/key.properties` exists:

1. **Notion RAG:** search Personal Assets for **Pomo Android Release Keystore** ([Notion page](https://www.notion.so/3d53dffea13981c4b366fe5dc35d4598), `Canonical` row).
2. **Download** `pomo-release.jks` from the row's **Drive URL** (Google Drive MCP or Composio `googledrive`).
3. **Write** `android/key.properties` using alias/passwords from the row **Notes** (default path: `~/Keys/pomo-release.jks`).
4. **Build** with `./scripts/build_android_release_apk.sh`. Do not generate a new keystore; OTA updates require the same key.

Local backup may also exist at `~/.cursor/secrets/pomo-android-keystore.env` on the owner's machine.

## Docs

- `README.md` - human product/install
- `DEPLOYMENT.md` - deployment, packaging, and release guide for agents
- `SPEC.md` / `specs/` - shipped contracts
- `CLAUDE.md` - detailed topology
- `ARCHITECTURE.md` - system design
- `DESIGN.md` - approved product design (2026-07-13)
- `TODOS.md` - open backlog
- `docs/superpowers/` - agent process rails + gap matrix
