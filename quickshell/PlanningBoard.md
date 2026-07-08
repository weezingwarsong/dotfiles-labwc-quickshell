# Planning Board

Design specs for all modules — both implemented and planned. Covers intended behavior, data dependencies, reveal conditions, and display logic.

---

## Pills

### Time

**File:** `module-pills/TimePill.qml`

**What we expect from the Time pill:**

1. When the user purposely wants to look at the time.
2. 10 minutes before a calendar event or task.
3. The user set a manual timer and it is about to run out.

**What we need to make it happen:**

- `ClockProcess` ✓ — ticks every second, exposes current time as a formatted string and raw datetime.
- **User-initiated peek (condition 1)** — W-1 keybind writes `showTime` to the FIFO. `PillController` handles it as a 5-second toggle peek. Mouse hover zone handled by `HoverZone` → `PillController`.
- `CalendarProcess` ✓ — `nextEvent.start` is watched; when the gap to now drops to 10 minutes, `shouldShow` becomes true.
- `TimerProcess` ✓ — `active` is watched; when true, `shouldShow` becomes true.

**Reveal conditions (`shouldShow: bool`):**

| Condition | Trigger | Auto-hide |
|---|---|---|
| Manual latch | `showTime` via FIFO or hover zone | Until dismissed (W-1 again) |
| Calendar imminent | next event ≤ 10 minutes away | when event start time passes |
| Timer/stopwatch active | `TimerProcess.active === true` | when timer finishes or stopwatch stops |

**Display text (`displayText: string`):**
- Timer or stopwatch active → `TimerProcess.displayText` (e.g. `"04:32"`)
- Otherwise → `ClockProcess.displayTime` (e.g. `"14:07"`)

**Testing via FIFO:**
```bash
echo "showTime" > ~/.local/share/pillbox/pillbox.fifo         # manual peek, 5s auto-hide
echo "setTimer:30" > ~/.local/share/pillbox/pillbox.fifo      # set 30s countdown
echo "startTimer" > ~/.local/share/pillbox/pillbox.fifo       # start it
echo "startStopwatch" > ~/.local/share/pillbox/pillbox.fifo   # stopwatch mode
```

---

### Workspace

**File:** `module-pills/WorkspacePill.qml`

**What we expect from the Workspace pill:**

A workspace OSD — any time the active workspace changes, regardless of cause (keybind, rofi window jump, script), the pill surfaces briefly to confirm the switch, then retreats.

**What we need to make it happen:**

- `WorkspaceProcess` ✓ — binds to `WindowManager.windowsets`. Derives `current` (the active `Windowset`) and `list` (all workspace names). Emits `workspaceChanged` on every switch.

**Reveal conditions (`shouldShow: bool`):**

| Condition | Trigger | Auto-hide |
|---|---|---|
| Workspace switched | `WorkspaceProcess.workspaceChanged` | 1.5 seconds after the last change |

`shouldShow` is driven entirely by a local `Timer` inside `WorkspacePill` — on `workspaceChanged`, the timer (re)starts; when it fires, `shouldShow` goes false. Re-triggering before the timer expires resets the countdown.

**Display text (`displayText: string`):**
- Current workspace name — e.g. `"1"`, `"2"`, or a named workspace like `"web"`

---

### Window

**File:** `module-pills/WindowPill.qml`

**What we expect from the Window pill:**

A transient indicator visible only while the window switcher panel is open. Shows the currently focused window's app glyph and `appId`. Retreats the instant the switcher closes.

**What we need to make it happen:**

- `ToplevelProcess` ✓ — exposes `focused` (`ToplevelManager.activeToplevel`) and `windows` (`ToplevelManager.toplevels`).

**Reveal conditions (`shouldShow: bool`):**

| Condition | Trigger | Auto-hide |
|---|---|---|
| Window switcher open | `panelController.activePanel === "windowSwitcher"` | when panel closes |

`shouldShow` is set by `shell.qml` as a binding — `WindowPill` has no internal timer or logic.

**Display (`visualComponent`):**
- Nerd Font glyph matched on `focused.appId` + `focused.appId` text label, both in `textPrimary`.

---

### MPRIS ✓

**File:** `module-pills/MprisPill.qml`

**What we expect from the MPRIS pill:**

Any time the state of a song changes — play, pause, or new track — the pill peeks briefly to confirm the event. While a track is active the MPRIS pill holds the winner slot over TimePill, so hover and explicit peek always surface MPRIS content.

**What we need to make it happen:**

- `MprisProcess` ✓ — binds to `Mpris.players`. Selects the most relevant player (Playing > Paused > first available). Emits `playerUpdated` on any track or playback state change.

**Stage 1 priority (`priority: int`):**
- `priority: 5` while `playbackState === Playing` and `trackTitle` is non-empty. Does not auto-expire — holds the winner slot for the duration of active playback. Drops to `0` when paused or stopped, letting `TimePill` win.

**Reveal conditions (`shouldReveal: bool` — Stage 2 content-driven peek):**

| Condition | Trigger | Auto-hide |
|---|---|---|
| Track changed | `MprisProcess.playerUpdated` (new track) | 3 seconds after last event |
| Playback state changed | `MprisProcess.playerUpdated` (play/pause/stop) | 3 seconds after last event |

`shouldReveal` is driven by a local `_peeking` flag + `Timer` — each `playerUpdated` signal restarts the timer; when it fires, `_peeking` goes false. Rapid events extend the peek window rather than stacking.

**Display (`visualComponent`):**
- Playback state glyph (Nerd Font): `String.fromCodePoint(0xf04b/0xf04c/0xf04d)` — play · pause · stop
- Track title from `activePlayer.trackTitle`

Layout: `[state glyph]  [trackTitle]` — glyph uses `fontNerd`, title uses `fontMono` (Qt falls back through fontconfig to Sarasa for CJK). Title elided right.

---

## Panels

### Calendar

**What we expect from the Calendar panel:**

The panel has three views: **glance** (default, compact), **expanded** (full week detail), and **timer** (dedicated timer/stopwatch widget). Navigation between views is explicit — each view has a back button or footer nav. No scrolling between views; each fills the panel surface independently.

**Glance view** — visible immediately when the panel opens:
1. Today's date — day of week, day, month, year.
2. Today's weather — current conditions, temperature, high/low.
3. Month view — mini calendar grid showing the current month. Days with events or tasks are visually marked with a dot indicator. Hovering a day shows a tooltip with that day's events and tasks. User can navigate forward/backward by month.
4. Today's events — list of events for the current day with their times (max 3, elided).
5. Today's tasks — task list for the current day (max 3, elided).
6. Footer buttons — `More ↓` (→ expanded view), `Timer` (→ timer view), `Edit ↗` (opens Google Calendar in browser).

**Expanded view** — full week detail, navigated to from the glance footer:
1. `↑ Back` — returns to glance view.
2. This week — all events across the next 7 days, grouped by date header.
3. Tasks this week — all tasks due in the next 7 days, grouped by date header.
4. 7-day forecast — daily weather conditions and high/low temperatures.

**Timer view** — dedicated timer/stopwatch, navigated to from the glance footer:

`_view === "timer"` in `CalendarPanel`. Content is rendered by `TimerWidget` (a separate component injected with `timerProcess`).

Layout (top to bottom):

1. `↑ Back` — returns to glance view.
2. **Display** — large monospaced `HH:MM:SS` digital clock face. Shows remaining time (countdown) or elapsed time (countup). Default state: `00:01:30`.
3. **Row 1** — two equal-width buttons:
   - `[Countdown | Countup]` — mode toggle. Clicking cycles between countdown and countup; switches `timerProcess.mode` and resets the display.
   - `[Start | Stop]` — running toggle. Starts or pauses the active mode.
4. **Row 2** — two equal-width buttons:
   - `[Xh:Xm:Xs]` — countdown duration button. Visible in countdown mode only. Label reflects the current `timerProcess.duration` formatted as the largest meaningful unit (e.g. `1m:30s`, `25m`, `1h`).
     - **Click** — expands an inline input field below the button. Accepts free-form time string in `Xh:Xm:Xs` format (each segment optional; e.g. `25m`, `1h:30m`, `1h:1m:1s`). Parsed on Enter; click outside dismisses without applying. Calls `timerProcess.setTimer(parsed)` on confirm.
     - **Scroll up** — `timerProcess.setTimer(timerProcess.duration + 5)`, minimum 5s.
     - **Scroll down** — `timerProcess.setTimer(Math.max(5, timerProcess.duration - 5))`.
   - `[Reset]` — stops and resets. Countdown: restores `remaining` to `duration`. Countup: resets `elapsed` to zero.

**Not in scope (by design):**
- In-panel event creation or editing — browser handles this. The panel is read-only except for the timer.
- Multiple calendar account switching — single Google account only.
- Timer persistence across Pillbox restarts — duration defaults to 1m 30s on each launch.

---

### Window Switcher

**File:** `module-panels/WindowSwitcherPanel.qml`

**What we expect from the Window Switcher panel:**

A keyboard-driven window switcher. W-Tab toggles the panel. When it appears, the filter `TextInput` has focus immediately — the user can start typing without clicking. Below the filter is a list of open windows. Arrow keys move the selection, Enter focuses the selected window and closes the panel. Clicking a row does the same. A second W-Tab press dismisses without focusing.

**Layout (top to bottom):**
1. **Filter input** — a styled `TextInput`, placeholder text `"Filter…"`. Typing narrows the list in real time (case-insensitive match against `appId + title`). Changing the filter text resets selection to index 0.
2. **Window list** — one row per matching toplevel. Each row: Nerd Font app glyph (fixed width, matched by `appId`) · app name (25% of row width, elided) · window title (remaining width, elided). The currently focused/active window is visually dimmed to distinguish it from the selection.

**Selection state:**
- Selected row: `accentBgColor` background, text and glyph use `textPrimary`.
- Hovered row (mouse): `surfaceLowColor` background; hovering a row syncs `selectedFlat` to that index.
- All other rows: transparent background, text uses `textNormal`, glyph uses `textMuted`.

**Keyboard behaviour:**
- `↑` / `↓` — move selection, clamped to list bounds.
- `Enter` — focus selected window via `toplevel.activate()`, emit `dismissed()`, close panel.
- `Escape` — emit `dismissed()`, close panel without focusing.

**Focus action:** `toplevel.activate()` — no subprocess, no `wlrctl`. Quickshell's `ToplevelManager` handles it natively.

**App glyph map** (Nerd Font, matched on `appId.toLowerCase()`):

| Pattern | Apps |
|---|---|
| terminal emulators | kitty, alacritty, foot, wezterm, … |
| Firefox | firefox, librewolf |
| Chromium-family | google-chrome, chromium, brave, edge |
| File managers | pcmanfm-qt, thunar, nautilus, dolphin |
| VS Code | code, vscodium |
| Neovim | nvim, neovim |
| Discord | discord |
| Steam | steam, steam_app_* |
| qBittorrent | qbittorrent |
| Media players | vlc, mpv, celluloid |
| Image viewers | imv, eog |
| Audio | pavucontrol, pavucontrol-qt |
| System monitor | btop |
| Fallback | everything else |

**What we need to make it happen:**

- `ToplevelProcess` ✓ — binds to `ToplevelManager`. Exposes `windows` (all toplevels as `ObjectModel`) and `focused` (`activeToplevel`).
- `WindowPill` ✓ — shows `focused.appId` + glyph; visible only while the switcher panel is open.
- `WindowSwitcherPanel` ✓ — pure visual consumer of `ToplevelProcess.windows`; no data fetching of its own.
- `PanelSurface` ✓ — requests `WlrKeyboardFocus.Exclusive` when active panel is `"windowSwitcher"`.
- W-Tab labwc keybind ✓ — writes `toggleWindowSwitcher` to the FIFO.

---

### Settings

**File:** `module-panels/SettingsPanel.qml` · **Keybind:** W-4

Full design notes, architecture decisions, and build plan live in **[settings.md](settings.md)**.

Summary: two tabs — **Services** (Google account + weather location, ✓ built) and **Appearance**
(typography, corner rounding, borders, ✓ built). Persistence via `SettingsProcess.qml` +
`Prefs.qml` singleton. See **[settings.md](settings.md)** for full design notes.

Appearance tab will gain a **Theme** section (planned) — a toggle to extract theme colors from the
current wallpaper. See [Wallpaper Panel](#wallpaper-panel) below for the extraction behavior.

---

### Media Player Panel

**File:** `module-panels/MediaPlayerPanel.qml` · **Keybind:** W-3

A panel dedicated to media playback control. Summoned deliberately by the user, distinct from the MPRIS pill which is passive and auto-reveals.

**Expected layout:**
- Album art (if available via MPRIS metadata)
- Track title + artist + album
- Playback controls: previous · play/pause · next
- Progress bar with current position and duration
- Volume control

**What we need:**
- `MprisProcess` ✓ — already exposes `activePlayer` with all needed properties
- `MediaPlayerPanel.qml` — panel UI consuming `MprisProcess.activePlayer`
- FIFO command `toggleMediaPlayer`, wired to `panelController.toggle("mediaPlayer")`
- `PanelSurface` Loader case for `"mediaPlayer"`
- labwc keybind W-3

---

### Wallpaper Panel

**File:** `module-panels/WallpaperPanel.qml` · **Keybind:** TBD (W-5 candidate)

**What we expect from the Wallpaper panel:**

A panel for managing the desktop background. Two tabs — **Color** (solid fill) and **Media** (image/video from files). Wallpaper is global, not per-workspace. Color extraction fires globally on every wallpaper change; the extraction toggle lives in the **Appearance tab of Settings**, not in this panel.

---

**Tab 1 — Color:**

A grid of 24 preset muted solid-color swatches. Click a swatch to apply immediately — no confirm step. Extraction does not fire (no image to analyze).

Preset swatches (24 colors):

| Hex | Name |
|---|---|
| `#282C34` | Dark Slate / One Dark |
| `#1E1E2E` | Catppuccin Mocha Base |
| `#2B303A` | Charcoal Navy |
| `#1A1B26` | Tokyo Night Dark |
| `#2F343F` | Arc Dark Gray |
| `#363B4E` | Muted Indigo |
| `#3B4252` | Nord Dark Blue |
| `#2D3748` | Cool Graphite |
| `#3C3836` | Gruvbox Dark Gray |
| `#2A323D` | Steel Blue Gray |
| `#434C5E` | Slate Slate |
| `#4A5240` | Muted Olive |
| `#3A4638` | Dark Sage |
| `#5B4B49` | Dusty Rose Brown |
| `#4C3A48` | Muted Plum |
| `#3E4A5B` | Storm Cloud Blue |
| `#5C6B73` | Ocean Slate |
| `#4A5568` | Slate Neutral |
| `#524B66` | Dusk Purple |
| `#6A5D52` | Warm Taupe |
| `#556B2F` | Muted Moss |
| `#38424D` | Deep Twilight |
| `#2F3E46` | Dark Forest Slate |
| `#1F232A` | Obsidian Black |

---

**Tab 2 — Media:**

Two stacked sections, each with a path input at the top for the source directory (configured inline, not in Settings — KISS). The same directory can serve both sections; filtering by extension separates them.

*Section 1 — Images:*
- Thumbnail grid: 3 rows fixed, scrollable horizontally. Each tile: small image preview (pcmanfm tile view style) with a truncated filename below; full filename shown on hover tooltip.
- Extensions: `.jpg`, `.jpeg`, `.png`, `.webp`, `.avif`.
- Mode toggle: `Single` | `Slideshow`.
- If Slideshow: interval stepper (seconds/minutes). Order: sequential only.
- Clicking a tile in Single mode applies immediately.
- Clicking a tile in Slideshow mode toggles it into the selection set (multi-select by clicking; all selected tiles cycle in order).

*Section 2 — Video / GIF:*
- Same thumbnail grid layout as Section 1. 3 rows fixed, scrollable horizontally.
- Extensions: `.mp4`, `.webm`, `.mkv`, `.mov`, `.gif`.
- Single selection only — click to apply. No slideshow.
- Thumbnail is a still frame extracted from the video (first frame, cached to `~/.cache/pillbox/thumbs/`).

---

**Color extraction (global behavior):**
- Toggle lives in the Appearance tab of Settings (`Prefs.extractColors: bool`, default off).
- Fires every time the wallpaper changes to an image or video.
- Does not fire in solid color mode.
- For video/GIF: extraction uses the same still frame as the thumbnail.
- Extractor choice (pywal, matugen, or custom): TBD — implement the rendering pipeline first, then choose the extractor once its output semantics are understood.

---

**yin IPC — resolved:**

yin uses a Unix socket at `/tmp/yin`. `yinctl` is the client binary that handles the binary protocol. Quickshell calls `yinctl` directly as a short-lived `Process` — no wrapper script needed.

Available commands:
```
yinctl --img <FILE>                   set wallpaper (image, gif, video)
yinctl --img <FILE> --output <NAME>   target a specific monitor
yinctl --play                         resume playback
yinctl --pause                        pause playback
yinctl --restore                      restore last cached wallpaper
```

**yin caches** pre-scaled video/image output in `~/.cache/yin/` keyed by `<width>x<height>_<filename>`. These are full-size renders, not usable as panel thumbnails.

---

**Solid color — does not use yin:**

yin has no solid color support. Color mode is handled entirely by quickshell: a fullscreen `PanelWindow` (`WlrLayer.Background`, `exclusiveZone: -1`) in `shell.qml` containing a solid `Rectangle`. `visible: wallpaperProcess.sourceType === "color"`. `color: wallpaperProcess.currentColor`. When the user switches to image/video mode this window hides and yin's render shows. No yin calls are made in color mode.

---

**Decisions made:**
- Global wallpaper only — no per-workspace assignment.
- Video = single selection only.
- Slideshow order: sequential only.
- Extraction toggle in Appearance (Settings), not in this panel.
- Source directory: path input inside the panel itself (KISS).
- Swatch click: immediate apply, no confirm.
- yin startup: labwc autostart, hard dependency. yin ✓ installed (`/usr/bin/yin`, `/usr/bin/yinctl`, AUR: `yin`).
- Thumbnail grid: 3 rows fixed, scroll horizontally. Tile = small image + truncated name below + tooltip on hover.
- No wrapper script — call `yinctl` directly from `Process`.

---

**Selection and active-state visuals — resolved:**

Two distinct states, two distinct indicators:
- **Currently active** (applies to all contexts — color swatches, image tiles, video tiles): accent border on the tile/swatch. One conditional `border.color` on the wrapping Rectangle.
- **Selected for slideshow** (image tiles only, slideshow mode): Nerd Font checkmark glyph anchored to a corner of the tile, `visible: selectedForSlideshow`. In single mode and for video/color, no checkmark appears — collapses to border-only.

---

**Startup restore behavior — resolved:**

`Prefs` is the source of truth, not yin's cache. On `WallpaperProcess.Component.onCompleted`:
- `sourceType === "color"`: color Rectangle shows immediately, no yin call.
- `sourceType === "image"` or `"video"` and `wallpaperPath !== ""`: call `yinctl --img <wallpaperPath>`. If the file no longer exists, catch the non-zero exit and log it.
- `wallpaperPath === ""` (first run, nothing set): do nothing — blank/compositor default.

This is more reliable than `yinctl --restore` because it does not depend on yin's cache being valid.

---

**Color mode + yin interaction — resolved:**

Solid color is a quickshell Background layer Rectangle that covers yin's surface. yin keeps running with its last image underneath (invisible). Switching back to image/video mode hides the Rectangle — yin's image reappears without any `yinctl` call. This is intentional: solid color is treated as a layer on top, not a yin state change.

---

**yin not running — resolved:**

`WallpaperProcess` catches non-zero exit from `yinctl` (error string: "Could not connect to IPC socket"). Logs to `/tmp/pillbox-wallpaper.log` with timestamp. Panel shows inline text: `"yin not started"` in the media section where the grid would otherwise appear.

---

**Remaining open questions:**

1. **Thumbnail cache cleanup** — `~/.cache/pillbox/thumbs/` accumulates ffmpeg-extracted stills over time. No cleanup strategy defined yet. TBD during implementation.

2. **Empty / unconfigured state** — what shows in each section if no directory is set or the directory has no matching files? A short placeholder text in each section (e.g., `"No images found"`, `"Set a directory above"`). Exact wording TBD.

---

**What we need:**
- `WallpaperProcess.qml` — owns wallpaper state; calls `yinctl` via short-lived `Process`; runs slideshow `Timer`; scans directory via `find` `Process`; persists state to Prefs.
- `WallpaperPanel.qml` — two-tab UI with color swatch grid and media thumbnail grids.
- Color background window in `shell.qml` — fullscreen `PanelWindow` at `WlrLayer.Background`, visible only in color mode.
- FIFO command `toggleWallpaper` → `panelController.toggle("wallpaper")` in `FifoListener` and `shell.qml`.
- `PanelSurface` Loader case for `"wallpaper"`.
- Video thumbnail extraction: `ffmpeg -i <file> -vframes 1 -vf scale=-1:80 ~/.cache/pillbox/thumbs/<name>.jpg` — called once per file, cached.
- New `Prefs` properties: `extractColors: bool`, `wallpaperSourceType: string`, `wallpaperPath: string`, `wallpaperDir: string`, `wallpaperColor: string`, `slideshowInterval: int`.
- labwc keybind (TBD, W-5 candidate) writing `toggleWallpaper` to FIFO.
- yin + yinctl ✓ installed (`/usr/bin/yin`, `/usr/bin/yinctl`); started via labwc autostart.
- Settings Appearance tab: new **Theme** section with `extractColors` toggle.
