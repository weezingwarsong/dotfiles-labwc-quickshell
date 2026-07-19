# Pillbox — Architecture

Pillbox is a Quickshell/QML desktop shell for **labwc** (Wayland). It replaces Waybar and similar bars with two distinct visual primitives: Pills and Panels.

---

## Core Concepts

### Pill

A rounded rectangle anchored top-center of the primary screen. Hidden by default. Context-aware — reveals automatically when relevant, hides when not. Only one pill is ever active at a time. The `PillWindow` is a dumb container; `PillController` decides what shows and when.

**Two-stage show/hide:**
- **Stage 1 — Winner:** each pill exposes `priority: int`; highest wins. Pre-computed so display is instant on reveal.
- **Stage 2 — Show/hide:** three independent triggers: hover (`HoverZone`), latch (W-1 FIFO toggle), or content-driven (`winner.shouldReveal`).

**Priority resolution table** — conditions are evaluated every frame; highest active priority wins:

| Priority | Pill | Active when | Beats |
|---|---|---|---|
| 1000 | `NotificationPill` | Critical notification, within 10 s of arrival | Everything |
| 200 | `WindowPill` | Window switcher panel is open | All except critical notification |
| 100 | `WorkspacePill` | Within 1.5 s of a workspace switch | TimePill urgent + MPRIS + normal notification + clock |
| 10 | `TimePill` (urgent) | Next calendar event ≤ 10 min away, **or** a countdown/stopwatch is running | MPRIS playing + normal notification |
| 6 | `NotificationPill` | Any notification, within 7 s of arrival | MPRIS playing |
| 5 | `MprisPill` | A player is in Playing state with a non-empty track title | Idle clock |
| 1 | `TimePill` (fallback) | Always — permanent floor so hover/latch always show something | — |
| 0 | any pill | When condition clears | — |

Key intent: critical notifications override everything. Normal notifications break through MPRIS but yield to workspace/window-switcher context. Imminent calendar events and active timers win over MPRIS (10 > 5). MPRIS playing wins over idle clock (5 > 1).

### Panel

A larger rounded rectangle below the Pill. Dumb and passive — no opinion about when to appear. Opens only on deliberate user action, closes only on deliberate dismiss (same keybind again, ESC, or click-outside). One panel at a time; summoning a second replaces the first immediately.

Panels are ordered in a navigation row matching their keybind positions. Left/right arrow keys and the floating `‹` `›` buttons in the top-right corner cycle the row. The window switcher is excluded from the row by design.

**Current panel order and keybinds:**

| Keybind | Panel | Status |
|---|---|---|
| W-2 | Calendar | ✓ built |
| W-3 | Media Player | ✓ built |
| W-4 | Settings | ✓ built |
| W-5 | Wallpaper | ✓ built |
| W-6 | Notifications | ✓ built |
| W-7 | Control | ✓ built |
| W-Tab | Window Switcher | ✓ built (excluded from nav row) |

**W-8** toggles the desktop visualizer overlay — not a panel; it is a `PanelWindow` at `WlrLayer.Bottom` managed directly in `shell.qml`.

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
                → processes called directly (e.g. timer.startTimer(), screenshot.takeRegion())
                → panelController.toggle("calendar") etc.

root-processes/ (instantiated in shell.qml)
    → ClockProcess, CalendarProcess, TasksProcess, TimerProcess, LocalTimerProcess,
      WeatherProcess, WorkspaceProcess, ToplevelProcess, MprisProcess,
      WallpaperProcess, SettingsProcess, NotificationServer,
      AudioProcess, NetworkProcess, ScreenshotProcess, ScreenrecProcess, CavaProcess
    → injected via properties into pills and panels

PillController (reads priority/shouldReveal from all pills)
    → PillWindow (dumb container, renders activePill.visualComponent)

PanelController (toggle / navigate)
    → PanelSurface (Loader, switches source by activePanel string)
        → CalendarPanel / ControlPanel / SettingsPanel / WallpaperPanel / etc.

WallpaperProcess (manages sourceType / currentPath / currentColor)
    → shell.qml wallpaperWindow (PanelWindow at WlrLayer.Background)
        → renders color rect / AnimatedImage / VideoOutput directly via Qt

CavaProcess (runs cava, parses bars[])
    → VisualizerSurface (PanelWindow at WlrLayer.Bottom)
        → RadialVisualizer (Canvas, bar rendering)

Colors.qml ← WallpaperProcess._readColorsProc (cat colors.json after matugen)
    → Style.qml bindings (mat3* roles)
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
| `openCalendarTimer` | Opens Calendar panel directly on the Timer view |
| `toggleMediaPlayer` | Opens / dismisses the Media Player panel |
| `toggleSettings` | Opens / dismisses the Settings panel |
| `toggleWallpaper` | Opens / dismisses the Wallpaper panel |
| `toggleNotifications` | Opens / dismisses the Notification panel |
| `toggleControl` | Opens / dismisses the Control panel |
| `toggleWindowSwitcher` | Opens / dismisses the Window Switcher panel |
| `toggleVisualizer` | Toggles the desktop visualizer overlay on/off |
| `setTimer:N` | Set countdown to N seconds |
| `startTimer` | Start or resume countdown |
| `pauseTimer` | Pause countdown |
| `resetTimer` | Reset countdown to original duration |
| `startStopwatch` | Start countup mode |
| `stopStopwatch` | Stop the countup |
| `resetStopwatch` | Reset countup to zero |
| `screenshotScreen` | Take a full-screen screenshot |
| `screenshotAll` | Take a screenshot of all outputs |
| `screenshotRegion` | Launch slurp region selector then screenshot |
| `screenshotUI` | Open Notifications panel on the Screenshots tab |
| `screenshotNotify:<path>` | Register an externally saved screenshot (shows toast) |
| `dismissToast:<id>` | Dismiss a specific toast by ID |
| `screenrecToggle` | Toggle fullscreen recording (oneshot) or toggle recording-to-file (replay) |
| `screenrecSaveReplay` | Save the current replay buffer |
| `screenrecSaveReplay:<N>` | Save the last N seconds of the replay buffer |
| `screenrecEmergencyStop` | Force-stop the recorder |
| `screenrecStartRegionWith:<coords>` | Start a region recording with pre-selected slurp coords |

**Test from terminal:**
```bash
echo toggleCalendar > ~/.local/share/pillbox/pillbox.fifo
echo "setTimer:30" > ~/.local/share/pillbox/pillbox.fifo && echo startTimer > ~/.local/share/pillbox/pillbox.fifo
echo toggleVisualizer > ~/.local/share/pillbox/pillbox.fifo
```

---

## Module Inventory

### Processes (`root-processes/`)

| File | Type | What it provides |
|---|---|---|
| `FifoListener.qml` | FIFO reader | External command bus; emits signals dispatched in `shell.qml` |
| `ClockProcess.qml` | Timer | `displayTime`, `displayTimeFull`, `now` (Date) |
| `CalendarProcess.qml` | gcal-fetch subprocess | `events`, `nextEvent`, `todayEvents`, `weekEvents`, `eventsByDate`, `lastUpdated`, `lastError` |
| `TasksProcess.qml` | gtask-fetch subprocess | `tasks`, `todayTasks`, `weekTasks`, `overdueTasks`, `tasksByDate`, `lastUpdated`, `lastError` |
| `TimerProcess.qml` | Pure QML timer | `mode`, `active`, `duration`, `remaining`, `elapsed`, `displayText`, `displayCenti` |
| `LocalTimerProcess.qml` | Multi-instance ephemeral timer | `register(id, durationMs)`, `kill(id)`, `status(id)`, `elapsed(id)`, `remaining(id)`; signal `timerCompleted(string id)`; tick auto-starts/stops with active timer count |
| `WeatherProcess.qml` | weather-fetch subprocess | `current` `{icon,temp,condition,high,low}`, `forecast` (7-day array) |
| `WorkspaceProcess.qml` | WindowManager binding | `current`, `list`, `currentIndex`, signal `workspaceChanged` |
| `ToplevelProcess.qml` | ToplevelManager binding | `windows` (ObjectModel), `focused` (activeToplevel) |
| `MprisProcess.qml` | Mpris binding | `players` (ObjectModel), `activePlayer`, signal `playerUpdated` |
| `WallpaperProcess.qml` | find + ffmpeg subprocesses | `sourceType`, `currentPath`, `currentColor`, `wallpaperDir`, `imageFiles`, `videoFiles`, `thumbsReady`, slideshow control, `lastError`; calls matugen for color extraction |
| `SettingsProcess.qml` | QtCore.Settings | `googleConnected`, `googleEmail`, `locationMode`, `locationString`; setters; signal `googleDisconnected` |
| `NotificationServer.qml` | D-Bus notification daemon | `notifications`, `countTotal`, `countCritical`; `clearAll()`; `getTimestamp(id)`; signal `newNotification` |
| `AudioProcess.qml` | PipeWire + wpctl | `sinkVolume`, `sinkMuted`, `sinkName`, `sourceVolume`, `sourceMuted`, `sourceName`; set/mute methods; polls every 3 s |
| `NetworkProcess.qml` | ip-route subprocess | `connected`, `localIp`; `toggleNetworking()` |
| `ScreenshotProcess.qml` | pillbox-screenshot script | `screenshots` (array), `lastPath`; `takeScreen()`, `takeAll()`, `takeRegion()`, `notifyExternalSave(path)`, `deleteScreenshot(path)`; signals `screenshotSaved`, `screenshotError` |
| `ScreenrecProcess.qml` | pillbox-screenrec script | `active`, `recording`, `recMode` ("oneshot"\|"replay"), `lastRecordingPath`, `lastReplayPath`; `toggle()`, `startRegionWith(coords)`, `saveReplay()`, `saveReplaySeconds(n)`, `emergencyStop()`; signals `recordingStarted`, `recordingStopped`, `replaySaved`, `recordingError` |
| `CavaProcess.qml` | cava subprocess | `bars[]` — array of normalized 0.0–1.0 amplitude values; exponentially smoothed (0.65 old + 0.35 new); `active` prop gates the process |

### Singletons (root)

| File | Purpose |
|---|---|
| `Prefs.qml` | Persists user preferences to `~/.config/pillbox.conf` (shared key namespace with SettingsProcess). Covers: font families, font sizes, pill/panel/element radius, border widths, padding, panel geometry (width%, offsetY%), wallpaper state (sourceType, path, color, dir, slideshow interval), media dirs, recMode, extractColors flag. Source of truth for everything `Style.qml` derives. |
| `Style.qml` | All visual tokens. Three sections: (1) Mat3 roles — live from `Colors.md3` (matugen-generated Material You roles, Nord fallbacks); (2) semantic mappings (`pillBgColor`, `accentColor`, `textNormal`, etc.); (3) Prefs-derived layout tokens (typography, radius, border widths, panel geometry). Never reads data from processes. |
| `Colors.qml` | Singleton bridge between matugen output and Style. Loads `~/.local/state/quickshell/generated/colors.json` on startup. `WallpaperProcess` calls `Colors.apply(jsonText)` after each matugen run to push new Material You roles in. `Style.qml` reads `Colors.md3`. |

### Reusable Elements (`module-reusable-elements/`)

| File | Role |
|---|---|
| `PillController.qml` | Stage 1+2 show/hide logic for pills. Pure `QtObject`. `triggerPeek()` toggles user latch. |
| `PillWindow.qml` | The pill's `PanelWindow`. Content-driven width. Dumb container. |
| `HoverZone.qml` | Always-present 8px transparent strip (10% screen width, anchored top) that detects cursor entry. `exclusiveZone: -1` so it overlaps other surfaces. |
| `PanelController.qml` | Manages which panel is open. `toggle(id)`, `navigate(dir)`, `panelOrder`. |
| `PanelSurface.qml` | The panel's `PanelWindow`. Fullscreen overlay. Loader switches source by `activePanel`. Keyboard focus, ESC dismiss, click-outside dismiss, floating nav buttons. Owns panel geometry (width/position/height cap). |
| `PanelNavBar.qml` | Standard first-row navigation bar for all panels (except WindowSwitcher). ‹/› buttons, right-aligned. |
| `PanelButton.qml` | Action button, 3 variants: default / accent / critical. Supports `icon` (Nerd Font glyph) or `label`. |
| `PanelCard.qml` | Raised section container (`surfaceLowColor` bg, configurable radius). |
| `PanelDivider.qml` | Full-width 1px horizontal rule. |
| `PanelTabBar.qml` | Full-width tab strip for panels with multiple top-level tabs (e.g. Settings: Appearance / Services). |
| `SectionHeader.qml` | Collapsible section header with tooltip; emits `onToggled`. |
| `SectionLabel.qml` | Small all-caps tracking label for panel sections. |
| `RowLabel.qml` | Label+value row layout helper used throughout Settings. |
| `StatusDot.qml` | 8px status indicator circle. Green = active, red = inactive. |
| `TogglePair.qml` | Two adjacent exclusive-select buttons. Supports `variant: "yesno"`. |
| `SegmentedControl.qml` | Multi-option exclusive selector (generalisation of TogglePair). |
| `IconButton.qml` | Nerd Font glyph button. |
| `ScrollingText.qml` | Clipped text that auto-scrolls when content overflows. Props: `text`, `color`, `maxWidth`, `pauseDuration`, `speed`, `font`. |
| `ScrollChip.qml` | Inline value chip with scroll-wheel increment/decrement and optional bar variant. |
| `FontPicker.qml` | Inline text input for font family names, committed on Return. |
| `MediaThumbnail.qml` | Image/video thumbnail element used in the Wallpaper panel grid. |
| `ToastWindow.qml` | `PanelWindow` that hosts `ScreenrecToast` and `ScreenshotPreview`. Positioned top-right. `dismiss(id)` dismisses a specific toast. |
| `ToastController.qml` | Logic layer for queuing and expiring toasts. |
| `ToastTimer.qml` | Auto-dismissing countdown used internally by ToastController. |
| `LocalTimer.qml` | Drop-in timer element backed by `LocalTimerProcess`. 5 variants: (1) process-only / no visual; (2) horizontal elapsed bar; (3) vertical elapsed bar; (4) horizontal remaining bar; (5) vertical remaining bar. Bars are 2px wide/tall, no borders or radius, smooth animation. `kill()` stops and removes the timer without emitting `completed()`. |

### Pills (`module-pills/`)

| File | Priority | `shouldReveal` trigger | Status |
|---|---|---|---|
| `TimePill.qml` | 10 (urgent) / 1 (fallback) | Calendar event ≤ 10 min, or timer/stopwatch active | ✓ built |
| `WorkspacePill.qml` | 100 | 1.5 s after workspace switch | ✓ built |
| `WindowPill.qml` | 200 | While window switcher is open | ✓ built |
| `MprisPill.qml` | 5 (playing) / 0 | 3 s after any track/state change | ✓ built |
| `NotificationPill.qml` | 1000 (critical) / 6 (normal) / 0 | 10 s (critical) or 7 s (normal) after arrival | ✓ built |
| `ScreenrecPill.qml` | TBD | TBD — screen recording indicator | 🔲 stub (file registered, no implementation) |

### Panels (`module-panels/`)

| File | Keybind | Contents | Status |
|---|---|---|---|
| `CalendarPanel.qml` | W-2 | Events list, tasks, 7-day weather, timer/stopwatch via `TimerWidget` | ✓ built |
| `MediaPlayerPanel.qml` | W-3 | MPRIS album art, track info, play/pause/prev/next, volume, playlist | ✓ built |
| `SettingsPanel.qml` | W-4 | Appearance tab (typography, padding, corners, borders, panel size, theme, wallpaper dir); Services tab (Google account, weather location) | ✓ built |
| `WallpaperPanel.qml` | W-5 | Color picker, image/video grid browser, slideshow controls | ✓ built |
| `NotificationPanel.qml` | W-6 | Scrollable notification cards; urgency tinting; actions; thumbnails; dismiss / clearAll; Screenshots tab | ✓ built |
| `ControlPanel.qml` | W-7 | Audio source/sink volume+mute chips; network IP status; screen recorder (oneshot/replay, screen/region); session (reconfigure, exit, reboot, shutdown with 3 s countdown) | ✓ built |
| `WindowSwitcherPanel.qml` | W-Tab | Wraps `WindowSwitcher`; excluded from nav row | ✓ built |
| `SysTrayBar.qml` | — | System tray strip; used inside `NotificationPanel` | ✓ built |
| `TimerWidget.qml` | — | Countdown/stopwatch widget; used inside `CalendarPanel` | ✓ built |

### Visualizer (`module-visualizer/`)

| File | Role |
|---|---|
| `VisualizerSurface.qml` | `PanelWindow` at `WlrLayer.Bottom` (behind all windows); 320×460; left-edge position; skewed canvas transform; hosts clock text + `RadialVisualizer`. Toggled by `shell.qml visualizerVisible` (W-8). |
| `RadialVisualizer.qml` | Canvas item that draws radial bar chart from `bars[]`. |

### Window Switcher (`module-window-switcher/`)

| File | Role |
|---|---|
| `WindowSwitcher.qml` | `QtObject` controller; `toggle()` API; `isOpen` property consumed by `WindowPill`. |
| `WindowSwitcherView.qml` | Full-screen panel view; filter input at top; keyed list of windows + apps. |
| `SelectableRow.qml` | Single keyboard-navigable row in the window switcher list. |

### Toasts (`module-toasts/`)

| File | Role |
|---|---|
| `ScreenrecToast.qml` | Toast content for recording state: pulsing red dot + elapsed timer while recording; filename + duration + open/copy-path after save. |
| `ScreenshotPreview.qml` | Toast content for screenshot save: thumbnail, filename, open/copy-path/delete. |

---

## Geometry

- **Screen reference:** `Quickshell.screens[0]` — primary screen only.
- **Pill:** `PanelWindow`, `anchors.top: true`, width content-driven, height `Style.fontSizePill + Style.pillPaddingV`. `margins.top: Screen.height * 0.02`.
- **Panel:** `PanelWindow`, width `Screen.width * Prefs.panelWidth / 100` (default 15%), height content-driven (capped at `Screen.height - 2 * panelY`). Top edge at `Screen.width * Prefs.panelOffsetY / 100` from screen top (default 10%).
- **Wallpaper window:** fullscreen `PanelWindow` at `WlrLayer.Background`, `exclusiveZone: -1`. Renders color rect / `AnimatedImage` / `VideoOutput` directly. No external wallpaper daemon. `WallpaperProcess` provides state; `shell.qml` owns rendering.
- **Visualizer:** `PanelWindow` at `WlrLayer.Bottom`, `exclusiveZone: -1`, 320×460, left-edge + 20% margin, no top/bottom anchor (compositor centers vertically). Visible when `shell.qml visualizerVisible === true`.

---

## Directory Structure

```
dotfiles-labwc-quickshell/          ← repo root
├── helper/
│   ├── calendar/gcal_fetch.py      (symlinked → ~/.local/bin/gcal-fetch)
│   ├── tasks/gtask_fetch.py        (symlinked → ~/.local/bin/gtask-fetch)
│   ├── weather/weather_fetch.py    (symlinked → ~/.local/bin/weather-fetch)
│   ├── google_auth_notify.sh       (symlinked → ~/.local/bin/google-auth-notify)
│   ├── screenshot/                 (pillbox-screenshot, pillbox-screenshot-region)
│   ├── screenrec/                  (pillbox-screenrec, pillbox-screenrec-region, pillbox-screenrec-saved)
│   └── kitty/kitty-theme.sh
│
├── quickshell/                     ← Pillbox shell (canonical source)
│   ├── CLAUDE.md                   ← session orientation; key invariants; dev workflow
│   ├── Colors.qml                  ← singleton; matugen colors.json → md3 roles
│   ├── Prefs.qml                   ← singleton; all user preferences persisted to pillbox.conf
│   ├── Style.qml                   ← singleton; all visual tokens (Mat3 roles → semantic names)
│   ├── shell.qml                   ← ShellRoot; instantiates everything; owns wallpaper window
│   ├── docs/                       ← project documentation (you are here)
│   ├── module-panels/
│   │   ├── CalendarPanel.qml       ✓
│   │   ├── ControlPanel.qml        ✓
│   │   ├── MediaPlayerPanel.qml    ✓
│   │   ├── NotificationPanel.qml   ✓
│   │   ├── SettingsPanel.qml       ✓
│   │   ├── SysTrayBar.qml          ✓ (used by NotificationPanel)
│   │   ├── TimerWidget.qml         ✓ (used by CalendarPanel)
│   │   ├── WallpaperPanel.qml      ✓
│   │   ├── WindowSwitcherPanel.qml ✓
│   │   └── qmldir
│   ├── module-pills/
│   │   ├── MprisPill.qml           ✓
│   │   ├── NotificationPill.qml    ✓
│   │   ├── ScreenrecPill.qml       🔲 (stub — registered, no implementation)
│   │   ├── TimePill.qml            ✓
│   │   ├── WindowPill.qml          ✓
│   │   ├── WorkspacePill.qml       ✓
│   │   └── qmldir
│   ├── module-reusable-elements/   ✓ all built
│   │   └── qmldir
│   ├── module-toasts/
│   │   ├── ScreenrecToast.qml      ✓
│   │   ├── ScreenshotPreview.qml   ✓
│   │   └── qmldir
│   ├── module-visualizer/
│   │   ├── RadialVisualizer.qml    ✓
│   │   ├── VisualizerSurface.qml   ✓
│   │   └── qmldir
│   ├── module-window-switcher/
│   │   ├── SelectableRow.qml       ✓
│   │   ├── WindowSwitcher.qml      ✓
│   │   ├── WindowSwitcherView.qml  ✓
│   │   └── qmldir
│   ├── root-processes/             ✓ all built
│   │   ├── LocalTimerProcess.qml   ✓ (multi-instance ephemeral timers)
│   │   └── qmldir
│   └── qmldir
│
├── matugen/
│   ├── config.toml                 ← template list + post_hook
│   └── templates/                  ← kvantum.kvconfig, kvantum.svg, colors.json, kitty, labwc/themerc
│
├── kvantum/
│   └── kvantum.kvconfig            ← sets active theme = Pillbox
│
├── labwc/
│   ├── rc.xml                      ← keybinds; window rules
│   ├── autostart                   ← quickshell, blueman-applet, rofi-polkit-agent
│   ├── environment                 ← PATH, QT_QPA_PLATFORMTHEME=qt6ct, TERMINAL
│   ├── menu.xml                    ← right-click menus
│   └── icons/                      ← white SVG icons for labwc menu
│
├── kitty/                          ← kitty config (theme generated by matugen)
├── pillbox/                        ← cava.conf; media/ symlinks (Screenshots, Recordings, Replays)
└── scripts/                        ← helper scripts (symlinked → ~/.config/scripts/)
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
echo toggleControl    > ~/.local/share/pillbox/pillbox.fifo
echo toggleVisualizer > ~/.local/share/pillbox/pillbox.fifo

# Check quickshell logs (filter noise)
ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1 | xargs strings | grep -v "Cannot install"
```

---

## External Dependencies

| Tool | Role |
|---|---|
| `matugen` | Material You color extraction from wallpaper images; generates `colors.json` and Kvantum/kitty/labwc theme files via templates |
| `ffmpeg` | Video thumbnail extraction for the Wallpaper panel grid (first keyframe at t=1s per video) |
| `gcal-fetch` | Google Calendar fetcher; `helper/calendar/gcal_fetch.py` → `~/.local/bin/` |
| `gtask-fetch` | Google Tasks fetcher; `helper/tasks/gtask_fetch.py` → `~/.local/bin/` |
| `weather-fetch` | Open-Meteo weather (no API key); `helper/weather/weather_fetch.py` → `~/.local/bin/` |
| `google-auth-notify` | Re-auth desktop notification + action button; `helper/google_auth_notify.sh` |
| `pillbox-screenshot` | Screenshot helper (grim + wl-copy); `helper/screenshot/` → `~/.local/bin/` |
| `pillbox-screenrec` | Screen recorder wrapper (gpu-screen-recorder); `helper/screenrec/` → `~/.local/bin/` |
| `cava` | Console audio visualizer; Pillbox reads its semicolon-delimited raw output |
| `JetBrains Mono Nerd Font` | All text + Nerd Font glyphs in Pillbox |
| `Sarasa Mono SC` | CJK font fallback (fontconfig) |
