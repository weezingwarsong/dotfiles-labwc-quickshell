# Pillbox — Architecture

Pillbox is a Quickshell/QML desktop shell for **labwc** (Wayland). It replaces Waybar and similar bars with two distinct visual primitives: Pills and Panels.

---

## Core Concepts

### Pill

A 24px rounded rectangle anchored top-center of the primary screen. Hidden by default. Context-aware — reveals automatically when relevant, hides when not. Only one pill is ever active at a time. The `PillWindow` is a dumb container; `PillController` decides what shows and when.

**Two-stage show/hide:**
- **Stage 1 — Winner:** each pill exposes `priority: int`; highest wins. Pre-computed so display is instant on reveal.
- **Stage 2 — Show/hide:** three independent triggers: hover (`HoverZone`), latch (W-1 FIFO toggle), or content-driven (`winner.shouldReveal`).

**Priority resolution table** — conditions are evaluated every frame; highest active priority wins:

| Priority | Pill | Active when | Beats |
|---|---|---|---|
| 200 | `WindowPill` | Window switcher panel is open | Everything |
| 100 | `WorkspacePill` | Within 1.5 s of a workspace switch | TimePill urgent + MPRIS + clock |
| 10 | `TimePill` (urgent) | Next calendar event ≤ 10 min away, **or** a countdown/stopwatch is running | MPRIS playing |
| 5 | `MprisPill` | A player is in Playing state with a non-empty track title | Idle clock |
| 1 | `TimePill` (fallback) | Always — permanent floor so hover/latch always show something | — |
| 0 | `MprisPill` / `WorkspacePill` | When condition clears | — |

Key intent: an imminent calendar event or active timer must win over now-playing MPRIS (10 > 5). When nothing urgent is happening, MPRIS playing wins over the idle clock (5 > 1).

### Panel

A larger rounded rectangle below the Pill. Dumb and passive — no opinion about when to appear. Opens only on deliberate user action, closes only on deliberate dismiss (same keybind again, ESC, or click-outside). One panel at a time; summoning a second replaces the first immediately.

Panels are ordered in a navigation row matching their keybind positions. Left/right arrow keys and the floating `‹` `›` buttons in the top-right corner cycle the row. The window switcher is excluded from the row by design.

**Current panel order and keybinds:**

| Keybind | Panel | Status |
|---|---|---|
| W-2 | Calendar | ✓ built |
| W-3 | Media Player | 🔲 planned |
| W-4 | Settings | ✓ built |
| W-5 | Wallpaper | ✓ built (testing + touch-up pending) |
| W-Tab | Window Switcher | ✓ built (excluded from nav row) |

---

## Target and Philosophy

**labwc only.** No Hyprland, Niri, or other compositor support. Data comes from standard Wayland protocols and Quickshell's built-in backends — no compositor-proprietary IPC.

**Functionality before visuals.** Every pill and panel must have its data plumbing and logic fully working before any visual layer is added. Build order for each module: (1) spec what it does, (2) write the process / data layer — validate via `console.log`, (3) wire the visual layer through `Style.qml`.

**One Source of Truth.** No pill or panel may fetch its own data. All data flows from `root-processes/` down. This makes the data layer independently testable and prevents duplicated IPC connections.

---

## Data Flow

```
labwc keybind
    → writes to ~/.local/share/pillbox/pillbox.fifo
        → FifoListener (SplitParser, always running)
            → signals dispatched to shell.qml
                → processes called directly (e.g. timer.startTimer())
                → panelController.toggle("calendar") etc.

root-processes/ (instantiated in shell.qml)
    → ClockProcess, CalendarProcess, TasksProcess, TimerProcess,
      WeatherProcess, WorkspaceProcess, ToplevelProcess, MprisProcess,
      WallpaperProcess, SettingsProcess
    → injected via properties into pills and panels

PillController (reads priority/shouldReveal from all pills)
    → PillWindow (dumb container, renders activePill.visualComponent)

PanelController (toggle / navigate)
    → PanelSurface (Loader, switches source by activePanel string)
        → CalendarPanel / SettingsPanel / WallpaperPanel / etc.
```

---

## FIFO Command Bus

**Pipe location:** `~/.local/share/pillbox/pillbox.fifo`

Write a command string (one per line) to trigger actions. `FifoListener.qml` tails the pipe and dispatches signals.

| Command | Effect |
|---|---|
| `showTime` | Latches the pill on (W-1 toggle); second call dismisses |
| `refreshCalendar` | Tells CalendarProcess to fetch immediately |
| `toggleCalendar` | Opens / dismisses the Calendar panel |
| `toggleWindowSwitcher` | Opens / dismisses the Window Switcher panel |
| `toggleSettings` | Opens / dismisses the Settings panel |
| `toggleWallpaper` | Opens / dismisses the Wallpaper panel |
| `setTimer:N` | Set countdown to N seconds |
| `startTimer` | Start or resume countdown |
| `pauseTimer` | Pause countdown |
| `resetTimer` | Reset countdown to original duration |
| `startStopwatch` | Start countup mode |
| `stopStopwatch` | Stop the countup |
| `resetStopwatch` | Reset countup to zero |

**Test from terminal:**
```bash
echo toggleCalendar > ~/.local/share/pillbox/pillbox.fifo
echo "setTimer:30" > ~/.local/share/pillbox/pillbox.fifo && echo startTimer > ~/.local/share/pillbox/pillbox.fifo
```

---

## Module Inventory

### Processes (`root-processes/`)

| File | Type | What it provides |
|---|---|---|
| `FifoListener.qml` | FIFO reader | External command bus; emits signals |
| `ClockProcess.qml` | Timer | `displayTime`, `displayTimeFull`, `now` (Date) |
| `CalendarProcess.qml` | gcal-fetch subprocess | `events`, `nextEvent`, `todayEvents`, `weekEvents`, `eventsByDate`, `lastUpdated`, `lastError` |
| `TasksProcess.qml` | gtask-fetch subprocess | `tasks`, `todayTasks`, `weekTasks`, `overdueTasks`, `tasksByDate`, `lastUpdated`, `lastError` |
| `TimerProcess.qml` | Pure QML timer | `mode`, `active`, `duration`, `remaining`, `elapsed`, `displayText`, `displayCenti` |
| `WeatherProcess.qml` | weather-fetch subprocess | `current` `{icon,temp,condition,high,low}`, `forecast` (7-day array) |
| `WorkspaceProcess.qml` | WindowManager binding | `current`, `list`, `currentIndex`, signal `workspaceChanged` |
| `ToplevelProcess.qml` | ToplevelManager binding | `windows` (ObjectModel), `focused` (activeToplevel) |
| `MprisProcess.qml` | Mpris binding | `players` (ObjectModel), `activePlayer`, signal `playerUpdated` |
| `WallpaperProcess.qml` | yinctl + find subprocesses | `sourceType`, `currentPath`, `currentColor`, `imageFiles`, `videoFiles`, slideshow control, `lastError` |
| `SettingsProcess.qml` | QtCore.Settings | `googleConnected`, `locationMode`, `locationString`; setters; signal `googleDisconnected` |

### Singletons (root)

| File | Purpose |
|---|---|
| `Prefs.qml` | Persists user preferences to `~/.config/pillbox/pillbox.conf`. All adjustable values (font sizes, radius scale, border widths, wallpaper state). Source of truth for everything `Style.qml` derives. |
| `Style.qml` | All visual tokens. Three sections: Variable (16-color Nord palette), Fixed (semantic mappings), Prefs-derived (live-updating tokens). Never reads data from processes. |

### Reusable Elements (`module-reusable-elements/`)

| File | Role |
|---|---|
| `PillController.qml` | Stage 1+2 show/hide logic for pills. Pure `QtObject`. |
| `PillWindow.qml` | The pill's `PanelWindow`. Content-driven width. Dumb container. |
| `HoverZone.qml` | Always-present 8px transparent strip that detects cursor entry. |
| `PanelController.qml` | Manages which panel is open. `toggle(id)`, `navigate(dir)`, `panelOrder`. |
| `PanelSurface.qml` | The panel's `PanelWindow`. Loader switches source by `activePanel`. Keyboard focus, ESC dismiss, click-outside dismiss, floating nav buttons. |
| `PanelNavBar.qml` | Standard first-row navigation bar for all panels (except WindowSwitcher). ‹/› buttons, right-aligned. |
| `PanelButton.qml` | Action button, 3 variants: default / accent / critical. |
| `PanelCard.qml` | Raised section container (`surfaceLowColor` bg, `radLg` corners). |
| `PanelDivider.qml` | Full-width 1px horizontal rule. |
| `SectionLabel.qml` | Small all-caps tracking label for panel sections. |
| `StatusDot.qml` | 8px status indicator circle. Green = active, red = inactive. |
| `TogglePair.qml` | Two adjacent exclusive-select buttons. |
| `IconButton.qml` | Nerd Font glyph button (used by PanelNavBar). |

### Pills (`module-pills/`)

| File | Priority | `shouldReveal` trigger | Status |
|---|---|---|---|
| `TimePill.qml` | 10 (urgent) / 1 (fallback) | Calendar event ≤ 10 min, or timer active | ✓ built |
| `WorkspacePill.qml` | 100 | 1.5 s after workspace switch | ✓ built |
| `WindowPill.qml` | 200 | While window switcher is open | ✓ built |
| `MprisPill.qml` | 5 (playing) / 0 | 3 s after any track/state change | ✓ built |
| `ScreenrecPill.qml` | TBD | TBD — screen recording indicator | 🔲 stub (file registered, no implementation) |

### Panels (`module-panels/`)

| File | Keybind | Status |
|---|---|---|
| `CalendarPanel.qml` | W-2 | ✓ built |
| `WindowSwitcherPanel.qml` | W-Tab | ✓ built |
| `SettingsPanel.qml` | W-4 | ✓ built |
| `WallpaperPanel.qml` | W-5 | ✓ built (testing + touch-up pending) |
| `MediaPlayerPanel.qml` | W-3 | 🔲 planned |

---

## Geometry

- **Screen reference:** `Quickshell.screens[0]` — primary screen only.
- **Pill:** `PanelWindow`, `anchors.top: true`, width content-driven (implicitWidth + 40), height 24px. `margins.top: Screen.height * 0.01`.
- **Panel:** `PanelWindow`, width `Screen.width * 0.15`, height content-driven (capped at `Screen.height - 2 * panelY`). Top edge at `Screen.width * 0.10` from screen top.
- **Color background (wallpaper):** fullscreen `PanelWindow` at `WlrLayer.Background`, `exclusiveZone: -1`. Visible only when `wallpaper.sourceType === "color"`.

---

## Directory Structure

```
dotfiles-labwc-quickshell/          ← repo root
├── helper/                         ← NOTE: currently at repo root, may contain old pre-rewrite scripts
│   ├── calendar/gcal_fetch.py      (in use — symlinked to ~/.local/bin/gcal-fetch)
│   ├── tasks/gtask_fetch.py        (in use — symlinked to ~/.local/bin/gtask-fetch)
│   ├── weather/weather_fetch.py    (in use — symlinked to ~/.local/bin/weather-fetch)
│   ├── google_auth_notify.sh       (in use — triggers re-auth desktop notification)
│   └── watcher/                    (review before use — may be from old implementation)
│
│   INTENT: all helpers required for Pillbox to function should eventually live under quickshell/,
│   so the shell is fully self-contained. helper/ at repo root is a migration target, not a home.
│
├── quickshell/                     ← Pillbox shell (canonical source)
│   ├── docs/                       ← project documentation (you are here)
│   ├── module-panels/
│   │   ├── CalendarPanel.qml       ✓
│   │   ├── MediaPlayerPanel.qml    🔲 (stub)
│   │   ├── SettingsPanel.qml       ✓
│   │   ├── TimerWidget.qml         ✓ (used by CalendarPanel)
│   │   ├── WallpaperPanel.qml      ✓ (testing pending)
│   │   ├── WindowSwitcherPanel.qml ✓
│   │   └── qmldir
│   ├── module-pills/
│   │   ├── MprisPill.qml           ✓
│   │   ├── ScreenrecPill.qml       🔲 (stub — registered, no implementation)
│   │   ├── TimePill.qml            ✓
│   │   ├── WindowPill.qml          ✓
│   │   ├── WorkspacePill.qml       ✓
│   │   └── qmldir
│   ├── module-reusable-elements/   ✓ all built
│   │   └── qmldir
│   ├── root-processes/             ✓ all built
│   │   └── qmldir
│   ├── Prefs.qml                   ✓
│   ├── Style.qml                   ✓
│   ├── qmldir
│   └── shell.qml                   ← ShellRoot; instantiates everything
└── scripts/                        ← legacy/system scripts (not Pillbox-specific)
```

---

## Common Dev Commands

```bash
# Restart quickshell
pkill -x quickshell; quickshell -p ~/Projects/github/dotfiles-labwc-quickshell/quickshell

# Test FIFO commands
echo toggleCalendar   > ~/.local/share/pillbox/pillbox.fifo
echo toggleSettings   > ~/.local/share/pillbox/pillbox.fifo
echo toggleWallpaper  > ~/.local/share/pillbox/pillbox.fifo

# Check quickshell logs (filter noise)
cat /run/user/1000/quickshell/by-id/*/log.qslog | grep -v "Cannot install"

# Wallpaper — test yinctl directly
yinctl --img /path/to/image.jpg
```

---

## External Dependencies

| Tool | Role | Location |
|---|---|---|
| `yin` | Wayland wallpaper daemon (ffmpeg-backed, video support) | `/usr/bin/yin` (AUR: `yin`) |
| `yinctl` | yin client CLI | `/usr/bin/yinctl` |

Available `yinctl` commands (Pillbox currently only uses `--img`):
```
yinctl --img <FILE>                 set wallpaper (image, gif, video)
yinctl --img <FILE> --output <NAME> target a specific monitor
yinctl --play                       resume playback
yinctl --pause                      pause playback
yinctl --restore                    restore last cached wallpaper (unreliable — avoid; use --img with stored path instead)
```

yin caches pre-scaled renders in `~/.cache/yin/` keyed by `<width>x<height>_<filename>` — these are full-size output frames, not usable as panel thumbnails. The separate `~/.cache/pillbox/thumbs/` cache (v2, ffmpeg) is needed for that.
| `gcal-fetch` | Google Calendar fetcher | `helper/calendar/gcal_fetch.py` → `~/.local/bin/` |
| `gtask-fetch` | Google Tasks fetcher | `helper/tasks/gtask_fetch.py` → `~/.local/bin/` |
| `weather-fetch` | Weather fetcher (Open-Meteo, keyless) | `helper/weather/weather_fetch.py` → `~/.local/bin/` |
| `google-auth-notify` | Re-auth desktop notification + action button | `helper/google_auth_notify.sh` |
| JetBrains Mono Nerd Font | All text + Nerd Font glyphs | `ttf-jetbrains-mono-nerd` |
| Sarasa Mono SC | CJK font fallback | `ttf-sarasa-gothic` |

yin must be running before Pillbox starts (labwc autostart — setup TBD). If yin is not running, `WallpaperProcess` logs the error and the panel shows `"yin not started"`.
