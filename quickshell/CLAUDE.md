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
| `docs/archive/completed.md` | Reverse-chronological log of completed work and key decisions |
| `docs/archive/LocalTimerDiscussion.md` | Design record for `LocalTimerProcess` + `LocalTimer` — multi-instance ephemeral timers, 5 variants, resolved decisions (archived, work complete) |
| `docs/archive/UselessPrettyThings.md` | Design + build record for orbital system graphs in ControlPanel — shader, oscillation, data pipeline (archived, work complete) |
| `docs/archive/ToastWindowAudit.md` | Pre-build audit of ToastWindow stack for NotificationToast integration — current state, gaps, file-by-file change list (archived) |
| `docs/archive/screenrecDiscussion.md` | Full design + build record for screenshot & screenrec system — scripts, QML processes, three toast modules, thumbnail pipeline, keyboard stack (archived, work complete) |
| `docs/archive/CarouselDiscussion.md` | Design + implementation record for `Carousel.qml` — viewport model, 3 size tiers, window rule, layout stack (archived, work complete) |
| `docs/archive/WallpaperPanelImageDiscussion.md` | Design record for WallpaperPanel image tab rewrite — PanelCard + SectionHeader + Carousel wiring (archived, work complete) |
| `docs/archive/screenshot_2026-07-18_20-43-18.png` | Reference sketch for Carousel viewport model (archived with discussion) |

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

## Thumbnail Pipeline

`WallpaperProcess` generates JPEG thumbnails for **both images and videos** via ffmpeg, cached at `~/.cache/pillbox/thumbs/`.

- **Videos**: `ffmpeg -ss 00:00:01 -frames:v 1` — first keyframe at 1s
- **Images**: `ffmpeg -vf scale=_thumbW:-1` — scaled to panel width (`Screen.width × Prefs.panelWidth / 100`), aspect ratio preserved
- `thumbPath(path)` → `cacheDir/filename.jpg` (works for any path)
- `thumbsReady` — reactive object map `path → true`; reassigned on each update so bindings re-evaluate
- Both image and video scans append to a shared serial queue; `scanDirectory()` resets it

**Carousel wiring**: pass `thumbsReady` and `thumbPath` as props; Carousel falls back to full path when thumb not ready yet.

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
