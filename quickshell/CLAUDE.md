# Pillbox — Claude Context

Pillbox is a Quickshell/QML desktop shell for **labwc** (Wayland). Two visual primitives: **Pills** (24px context-aware bar, one active at a time) and **Panels** (deliberate-open overlays). Read `docs/architecture.md` first if you have no prior context.

---

## Docs

| File | What it covers |
|---|---|
| `docs/architecture.md` | Core concepts, data flow, FIFO bus, module inventory, directory tree, dev commands |
| `docs/modules.md` | Root process specs, pill behavior, panel behavior — built and planned |
| `docs/style-system.md` | Token system, Prefs.qml, Style.qml, palette, v2 roadmap |
| `docs/components.md` | Reusable visual elements in `module-reusable-elements/` |
| `docs/completed.md` | Reverse-chronological log of completed work and key decisions |
| `docs/CarouselDiscussion.md` | Full design + implementation spec for `Carousel.qml` (new reusable element) — viewport model, 3 size tiers, window rule, Phase 2 layout stack, Phase 3 steps |
| `docs/WallpaperPanelImageDiscussion.md` | Spec for replacing WallpaperPanel's image tab with PanelCard + SectionHeader + Carousel |
| `docs/screenshot_2026-07-18_20-43-18.png` | Reference sketch — hand-drawn viewport model for Carousel (container clipping, image spanning full row width, CON2→HERO transition) |

---

## Key Invariants

**Never break these without discussion:**

- **One Source of Truth** — no pill or panel fetches its own data. All data flows from `root-processes/` and is injected down via properties.
- **Functionality before visuals** — data layer works and logged before any visual layer is added. Style system is wired last.
- **One panel at a time** — `PanelController.toggle(id)` enforces this. Summoning a second panel replaces the first immediately.
- **One pill at a time** — `PillController` picks the highest-priority winner every frame. Hover and W-1 latch are PillController universals — not pill-specific logic.
- **PanelSurface owns geometry** — individual panels are content only. Width, position, and height cap live in `PanelSurface.qml`.

---

## Development Workflow

Quickshell config is symlinked — **edit files directly in this repo**, changes are live in the actual running config.

**Restart quickshell to apply changes:**
```bash
pkill -x quickshell; quickshell -p ~/Projects/github/dotfiles-labwc-quickshell/quickshell
```

**Test FIFO commands directly:**
```bash
echo toggleCalendar  > ~/.local/share/pillbox/pillbox.fifo
echo toggleSettings  > ~/.local/share/pillbox/pillbox.fifo
echo toggleWallpaper > ~/.local/share/pillbox/pillbox.fifo
echo "setTimer:30"  > ~/.local/share/pillbox/pillbox.fifo && echo startTimer > ~/.local/share/pillbox/pillbox.fifo
```

**Check logs (use newest session file):**
```bash
ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1 | xargs strings | grep -v "Cannot install"
```

**Never run sudo via Bash** — hand the command to the user to paste themselves.

---

## Adding a New Module

Every new QML file must be registered in its directory's `qmldir` before it can be imported. This is a common source of "unknown component" errors.

New process in `root-processes/`:
1. Add QML file
2. Register in `root-processes/qmldir`
3. Instantiate in `shell.qml`
4. Inject into pills/panels via properties

New panel in `module-panels/`:
1. Add QML file
2. Register in `module-panels/qmldir`
3. Add FIFO command to `FifoListener.qml`
4. Add Loader case + process injection in `PanelSurface.qml`
5. Add to `PanelController.panelOrder` (if it belongs in the nav row)
6. Wire `onToggle*Requested` in `shell.qml`
7. Add labwc keybind to `rc.xml`

---

## Fix Candidates

Several known issues are tracked in the docs as **fix candidates** and intentionally deferred. Do not fix them without being asked. Key ones:

- ~~Pill dimension tokens (`pillHeight: 24`, `pillPaddingH: 20`, etc.) are hardcoded; should be Style tokens~~ **Fixed** — `pillPaddingV` added to Prefs/Style; pill height is now `Style.fontSizePill + Style.pillPaddingV`; font size cap raised to 24
- ~~`textMuted` should be `color3`, currently `color4` (same as `textSecondary`)~~ **Fixed** — mat3 pipeline: `textMuted` now maps to `mat3Outline`, which is genuinely dimmer than `textSecondary` (`mat3OnSurfaceVariant`)
- ~~`borderAccentColor` is redundant with `accentColor` — both `color10`; remove one~~ **Fixed** — `borderAccentColor` removed from Style; callsites use `accentColor` directly
- ~~`textWeekend` and `dotIndicator` are single-use CalendarPanel tokens; should move inline~~ **Fixed** — both removed from Style; CalendarPanel uses `accentColor` inline
- ~~Email address not shown in Settings Services tab~~ **Fixed** — `gcal-fetch --email` reads primary calendar id (= Gmail address) via calendar.readonly scope; `SettingsProcess` exposes `googleEmail`; displayed below "Connected" in `textMuted`/`fontSizeSubtle`
- ~~Click-outside dismiss disabled for WindowSwitcher~~ **Fixed** — removed `enabled: activePanel !== "windowSwitcher"` guard from PanelSurface dismiss MouseArea
- ~~User preference changes don't persist across quickshell restarts~~ **Fixed** — see completed.md
- ~~TimePill urgent state has no distinct visual treatment~~ **Fixed** — calendar imminent uses `accentBgColor` + scrolling marquee; countdown < 10s uses `criticalBgColor` + `textCritical` + centiseconds

---

## Commit Timing

**Do not commit mid-session during design or docs work.** Batch all commits and push once at session end.

---

## Google Calendar Auth

OAuth tokens are stored outside the repo. Testing-mode app — refresh tokens expire after 7 days. Re-auth: open Settings panel → Re-authenticate. Credentials live in `~/.config/pillbox/` (not tracked).
