# Pomo: Technical Specification (index)

**Repo:** `github.com/rawshn97/pomo` (forked from `recoskyler/pomo`) · **Branch:** `main`  
**Audience:** product, developers, and agents  

This file is the **entrypoint**. Shipped contracts live under [`specs/`](specs/). Edit the feature file you care about; keep this index short.

| Doc | Role |
|-----|------|
| **[SPEC.md](SPEC.md)** (this file) | Index + reading order |
| **[specs/](specs/)** | Shipped per-feature specs (what is built) |
| **[SPEC_IN_PROGRESS.md](SPEC_IN_PROGRESS.md)** | Approved or discussed, not shipped |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | System design detail (Cubits, Android FGS, webhooks) |
| **[DESIGN.md](DESIGN.md)** | Original product design (2026-07-13); not a shipped inventory |
| **[docs/superpowers/DESIGN-GAP-MATRIX.md](docs/superpowers/DESIGN-GAP-MATRIX.md)** | DESIGN vs shipped status |
| **[AGENTS.md](AGENTS.md)** | Agent operating rules |
| **[README.md](README.md)** | Human setup / install |

---

## Spec map (work by module)

| Spec | Feature | Module path |
|------|---------|-------------|
| [specs/overview.md](specs/overview.md) | Purpose, shell, flavors, platforms | (app-wide) |
| [specs/shared.md](specs/shared.md) | Prefs, models, helpers, constraints | `lib/singletons/`, `lib/helpers/`, `lib/models/` |
| [specs/timer.md](specs/timer.md) | Pomodoro focus timer + PARA task sessions | `lib/pages/timer/`, `lib/pages/tasks/` |
| [specs/hourly-tracker.md](specs/hourly-tracker.md) | Activity tags, 24h grid, missed hours | `lib/pages/tracker/` |
| [specs/activity-tags.md](specs/activity-tags.md) | Auto-generated tag registry snapshot | `specs/activity-tags.md` |
| [specs/notion.md](specs/notion.md) | Dual Notion DBs, sync queues, tag registry | `lib/services/notion_*.dart` |
| [specs/settings.md](specs/settings.md) | Settings UI and `SettingsCubit` | `lib/pages/settings/`, `lib/widgets/settings_segments/` |
| [specs/desktop.md](specs/desktop.md) | macOS menu bar, overlay, notifications, login | `lib/desktop/` |
| [specs/android.md](specs/android.md) | FGS timer tile, exact hourly alarms | `lib/services/android_*`, `android/` |
| [specs/web.md](specs/web.md) | PWA, notifications, Picture-in-Picture | `lib/services/web_pwa_*`, `deploy/` |
| [specs/ops.md](specs/ops.md) | Setup, verify, build, flavors, CI footguns | `scripts/` |

**PM tip:** change one feature → edit that one file under `specs/`. Cross-cutting Prefs keys and Notion IDs → `specs/shared.md`. Unshipped ideas → `SPEC_IN_PROGRESS.md`, not the shipped feature files.

---

## Capabilities (at a glance)

| Feature | Summary |
|---------|---------|
| **Focus timer** | Work / short break / long break laps; optional hourly tag credit |
| **PARA task sessions** | Pick a Notion task; live Time Logs rows; manual missed-time log |
| **Hourly tracker** | 24h grid + analytics; multi-tag 60m split; missed hours; timer can add minutes |
| **Activity tags** | Defaults + custom (name, emoji, color); Notion registry + tombstones |
| **Quiet hours** | Suppress hourly chimes; auto-fill Sleep & Rest on empty slots |
| **Webhooks** | RGB JSON to comma-separated URLs on timer events (HomeAssistant) |
| **macOS desktop** | Menu bar, floating overlay, desktop notifications, launch at login |
| **Android** | Timer FGS + hourly exact alarms + 1-tap Log Work / Switch Tag / Open Grid |
| **Web PWA** | Browser run + `./scripts/build-web.sh`; notifications / PiP where supported |

**Not shipped extras:** Overlay tag picker (overlay stays display-only). SSE live tag push.

---

## Document history

| Date | Change |
|------|--------|
| 2026-09-03 | SPEC.md becomes index; shipped inventory split into `specs/*.md` (LinkedIn Tools layout) |
| 2026-09-03 | Timer hourly tag credit (Approach A) shipped |
