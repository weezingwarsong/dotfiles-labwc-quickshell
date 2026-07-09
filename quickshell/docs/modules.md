# Module Specs

Design decisions, behavior specs, and implementation notes for every pill and panel — both built and planned.

For reusable UI building blocks, see [components.md](components.md).
For Style.qml / Prefs.qml token system, see [style-system.md](style-system.md).

---

## Root Process Details

Operational details for the data-layer processes in `root-processes/`. The Module Inventory in [architecture.md](architecture.md) lists what each process exposes; this section covers fetch behavior, output schemas, and constraints relevant to panels consuming the data.

### CalendarProcess

- **Fetch window:** 3 months back to 24 months ahead, max 250 events. Wide window so the calendar panel can navigate months client-side without re-fetching.
- **Startup delay:** 10 seconds before first fetch — lets the network settle.
- **Repeat:** Every 5 minutes after first fetch. Immediate on `refreshCalendar` FIFO command.
- **Error log:** `/tmp/pillbox-google.log` (timestamps + error details).
- **Event date format:**
  - Timed events — ISO 8601 with timezone: `"2026-07-04T14:00:00+08:00"`
  - All-day events — date-only string: `"2026-07-04"`
  - `allDay: bool` property distinguishes them.

### TasksProcess

- **Fetch scope:** All incomplete tasks + completed tasks from the last 30 days.
- **Startup/repeat/error:** Same as CalendarProcess (10s delay, 5-minute repeat, same error handling).
- **Output schema per task:**
  ```json
  {
    "id": "...",
    "title": "Task title",
    "status": "needsAction | completed",
    "due": "2026-07-04",
    "notes": "optional description or null",
    "listTitle": "My Tasks",
    "listId": "..."
  }
  ```
- `due` is `null` if no due date is set. Tasks without a due date appear in `tasks` but are excluded from all date-keyed views (`todayTasks`, `weekTasks`, `tasksByDate`).

### WeatherProcess

- **Refresh:** Every 30 minutes (plus 10-second startup delay).
- **Icon format:** Hex string codepoint (e.g. `"f185"`), rendered via `String.fromCharCode(parseInt(icon, 16))`. Uses Nerd Font codepoints.

### MprisProcess

Full `MprisPlayer` property and method reference — needed for MediaPlayerPanel:

| Member | Type | Notes |
|---|---|---|
| `playbackState` | `MprisPlaybackState` | `.Playing` / `.Paused` / `.Stopped` |
| `trackTitle` | `string` | Current track name |
| `trackArtist` | `string` | Current track artist |
| `trackAlbum` | `string` | Current track album |
| `isPlaying` | `bool` | Convenience alias for `playbackState === Playing` |
| `togglePlaying()` | method | Play/pause toggle |
| `next()` | method | Skip to next track |
| `previous()` | method | Skip to previous track |

Player selection: `_selectPlayer()` runs on every state/track change — picks Playing > Paused > first available.

---

## Pills

### Time Pill ✓

**File:** `module-pills/TimePill.qml`

**What it does:** Shows the current time. Also serves as the fallback winner when no other pill has a reason to show — TimePill is always lurking at priority 1 so hover and latch always surface something useful.

**Data sources (injected):** `ClockProcess`, `CalendarProcess`, `TimerProcess`

**Stage 1 priority:**
- `priority: 10` when a calendar event is ≤ 10 minutes away, or when a timer/stopwatch is active
- `priority: 1` always (permanent fallback — never drops to 0)

**Content-driven `shouldReveal` conditions** (TimePill-specific — evaluated every frame):

| Condition | Trigger | Auto-hide |
|---|---|---|
| Calendar imminent | next event ≤ 10 min away | when event start time passes |
| Timer/stopwatch active | `TimerProcess.active === true` | when timer finishes / stopwatch stops |

Hover and W-1 latch are **not** TimePill-specific — they are universal `PillController` behaviors that reveal whatever pill is currently winning. They apply regardless of `shouldReveal`.

**Display (`displayText`):**
- Timer or stopwatch active → `TimerProcess.displayText` (e.g. `"00:01:30"`)
- Otherwise → `ClockProcess.displayTime` (e.g. `"14:07"`)

**Visual urgent state (not yet built):** When `_calendarImminent` or `_timerActive` is true (priority 10), the pill currently looks identical to the idle clock. The intent is a distinct urgent visual treatment — `criticalBgColor` is the candidate background. Deferred until all panels are feature-complete.

---

### Workspace Pill ✓

**File:** `module-pills/WorkspacePill.qml`

**What it does:** Workspace OSD — any time the active workspace changes (keybind, rofi window jump, script), the pill surfaces briefly to confirm the switch.

**Data sources (injected):** `WorkspaceProcess`

**Stage 1 priority:** `priority: 100` for 1.5 seconds after each switch, `0` otherwise.

**Stage 2 reveal:** Driven by a local `Timer` inside `WorkspacePill` — restarted on each `workspaceChanged`; fires `shouldReveal = false` after 1.5 s. Rapid switches extend the window.

**Display:** Current workspace name (left) + Nerd Font radiobox glyphs (one per workspace, active/inactive, right).

---

### Window Pill ✓

**File:** `module-pills/WindowPill.qml`

**What it does:** Transient indicator visible only while the window switcher panel is open. Shows the focused window's app glyph and `appId`.

**Data sources (injected):** `ToplevelProcess`

**Stage 1 priority:** `priority: 200` while switcher is open, `0` otherwise. Always highest — switcher is explicitly user-invoked, so it should dominate.

**Stage 2 reveal:** Set externally by `shell.qml` as a binding: `shouldReveal: panelController.activePanel === "windowSwitcher"`. No internal timer or logic.

**Display:** Nerd Font glyph (matched on `focused.appId`) + `focused.appId` text.

---

### MPRIS Pill ✓

**File:** `module-pills/MprisPill.qml`

**What it does:** Peeks briefly whenever the playing track or playback state changes. While actively playing, holds the winner slot over TimePill so hover and latch always surface MPRIS content.

**Data sources (injected):** `MprisProcess`

**Stage 1 priority:** `priority: 5` while `playbackState === Playing` and `trackTitle` non-empty. Drops to `0` when paused or stopped. Never auto-expires — holds the slot for the full duration of active playback.

**Stage 2 reveal:** `shouldReveal` is true for 3 seconds after any `playerUpdated` event (track change or playback state change). Driven by local `_peeking` flag + `Timer`. Rapid events extend the peek window.

**Display:** Playback state glyph (`String.fromCodePoint(0xf04b/0xf04c/0xf04d)`) + track title. CJK track names handled transparently via fontconfig.

---

## Panels

### Calendar Panel ✓

**File:** `module-panels/CalendarPanel.qml` · **Keybind:** W-2

**Data sources (injected):** `ClockProcess`, `CalendarProcess`, `TasksProcess`, `WeatherProcess`, `TimerProcess`

**Three views** — navigated by explicit buttons, not gestures:

**Glance** (default on open):
1. Date header — day of week, day, month, year
2. Current weather — icon, temp, condition, high/low
3. Month grid — mini calendar; days with events/tasks get dot indicators; month navigation arrows
4. Today's events — up to 3, with times
5. Today's tasks — up to 3
6. Footer: `More ↓` (→ expanded) · `Timer` (→ timer view) · `Edit ↗` (Google Calendar in browser)

**Expanded** (from footer `More ↓`):
- `↑ Back` → glance
- 7-day events grouped by date
- 7-day tasks grouped by due date
- 7-day weather forecast (icon + condition + high/low per day)

**Timer view** (from footer `Timer`):
- `↑ Back` → glance
- `TimerWidget` component — large HH:MM:SS display, mode toggle (countdown/countup), start/stop, duration input, reset. Calls `TimerProcess` methods directly — no FIFO round-trip.

**Design decisions:**
- Read-only for calendar/tasks — no in-panel event creation. Browser handles editing.
- Single Google account only.
- Timer state does not persist across Pillbox restarts (defaults to 1m 30s on launch).

---

### Window Switcher Panel ✓

**File:** `module-panels/WindowSwitcherPanel.qml` · **Keybind:** W-Tab

**Data sources (injected):** `ToplevelProcess`

**Behavior:** Keyboard-driven. Filter `TextInput` has focus immediately on open — user can type without clicking. List below filter narrows in real time (case-insensitive match on `appId + title`). Arrow keys move selection, Enter focuses window + closes panel, Escape closes without focusing.

**Layout:**
1. Filter input (placeholder "Filter…")
2. Window list — each row: Nerd Font glyph (fixed width) · app name (25% width, elided) · window title (remaining, elided)

**Selection states:** selected = `accentBgColor` bg + `textPrimary`; hovered (mouse) = `surfaceLowColor` bg; hovering syncs `selectedFlat` index; rest = transparent bg + `textNormal`.

**Activation:** `toplevel.activate()` — native Quickshell ToplevelManager call, no subprocess.

**Note:** Excluded from the panel navigation row by design. Has its own dedicated dismiss path (`dismissed()` signal).

`WlrKeyboardFocus.Exclusive` is set by `PanelSurface` for all open panels. For normal panels (Calendar, Settings, Wallpaper) this serves two purposes: (1) enables click-outside dismiss detection, (2) allows keyboard arrow navigation and ESC to work without a click first. WindowSwitcher shares both of those, and additionally uses the exclusive focus to auto-route keyboard input into the filter `TextInput` on open.

Click-outside dismiss should work for WindowSwitcher the same as other panels.

> **Fix candidate:** Click-outside dismiss is currently disabled for WindowSwitcher in `PanelSurface` (`enabled: root.activePanel !== "windowSwitcher"`). It should be re-enabled — intended dismiss paths are Escape, Enter (activate window), direct row click, **and** click-outside.

**App glyph map** (Nerd Font, matched on lowercased `appId`): terminal emulators, Firefox, Chromium-family, file managers, VS Code, Neovim, Discord, Steam, qBittorrent, media players (VLC/mpv), image viewers (imv), audio (pavucontrol), system monitor (btop), fallback for everything else.

---

### Settings Panel ✓

**File:** `module-panels/SettingsPanel.qml` · **Keybind:** W-4

**Data sources (injected):** `SettingsProcess`, `CalendarProcess`, `TasksProcess`

Two tabs — `[ Services ] [ Appearance ]` — rendered as two `ColumnLayout` children with `visible: _tab === "..."`. `PanelNavBar` as first row.

#### Services tab ✓

**Google Account card:**
- Connected: email (read from token file) · per-service last-fetch timestamps and error state (`CalendarProcess.lastError` / `TasksProcess.lastError`: `""` ok / `"auth"` / `"network"`) · `[Re-authenticate]` (calls `google-auth-notify.sh` → terminal + `gcal-fetch --auth`) · `[Disconnect]` (revoke + delete token + clear log + `settingsProcess.disconnect()` + `clearData()` on both processes)
- Not connected: `○ Not connected` · `[Connect]` (same flow as Re-authenticate)

> **Fix candidate:** Email is not currently shown. The connected state shows the text "Connected" rather than the account email address. Intent: read email from the stored token file and display it here so the user knows which account is linked.

**Weather Location card:**
- `[ Auto ] [ Manual ]` toggle — `Auto` = IP geolocation via ipapi.co; `Manual` = city name or `lat,lon` passed to `weather-fetch --location`
- Manual mode shows a `TextInput` + `[Apply]` button; an immediate re-fetch fires on apply

#### Appearance tab ✓

All 7 `Prefs` properties get a live-updating control. Changes apply immediately — no Save step.

**Typography card:**
- Pill text size stepper (range 10–18) → `Prefs.fontSizePill`
- Panel text size stepper (range 8–14) → `Prefs.fontSizeBase`
- Mono font text input → `Prefs.fontMono` (apply on Enter/blur)
- Glyph font text input → `Prefs.fontNerd` (apply on Enter/blur)

**Corner rounding card:** Three-way selector `[None] [Subtle] [● Default]` → `Prefs.radiusScale` (0.0 / 0.5 / 1.0)

**Borders card:** Two three-way selectors:
- Container border `[Off] [● Thin] [Thick]` → `Prefs.borderWidth` (0 / 1 / 2)
- Element border `[Off] [● Thin] [Thick]` → `Prefs.elementBorderWidth` (0 / 1 / 2)

**Reset to defaults:** `PanelButton { variant: "critical"; label: "Reset to defaults" }` — calls every `Prefs.set*()` with its default value.

#### Theme section (planned, v2)

A toggle `extractColors: bool` (default off) in the Appearance tab. Fires on every wallpaper change to image/video. Extractor TBD (pywal / matugen / custom) — implement after wallpaper panel stabilizes.

---

### Wallpaper Panel ✓ (testing + touch-up pending)

**File:** `module-panels/WallpaperPanel.qml` · **Keybind:** W-5

**Data sources (injected):** `WallpaperProcess`

Two tabs — `[ Color ] [ Media ]` — `PanelNavBar` as first row. Wallpaper is global (not per-workspace). Color extraction is a future toggle in Settings → Appearance, not in this panel.

#### Color tab

24 preset muted solid-color swatches in a 6-column grid. Click applies immediately — no confirm. Active swatch has accent border. Tooltips show the color name. Does not call yin — solid color is rendered by a fullscreen `PanelWindow` at `WlrLayer.Background` in `shell.qml` (`color: wallpaper.currentColor`, `visible: wallpaper.sourceType === "color"`).

Preset palette: 24 swatches ranging from very dark near-blacks to muted mid-tones (Nord Dark Blue `#3B4252`, Catppuccin Mocha `#1E1E2E`, Gruvbox Dark `#3C3836`, etc.). Full list in `WallpaperPanel.qml` `_swatches` property.

#### Media tab

**Directory input:** `TextInput` + `[Scan]` button → calls `wallpaperProcess.scanDirectory(dir)`. Persisted to `Prefs.wallpaperDir`.

**Images section:**
- `[ Single ] [ Slideshow ]` mode toggle
- Slideshow controls (visible in slideshow mode): `[–]` interval `[+]` stepper (±5 s, min 5 s; persisted to `Prefs.slideshowInterval`) + `[Apply]` button — starts slideshow with selected tiles (or all images if none selected)
- 3-row horizontally-scrollable thumbnail grid (`Grid { rows: 3; flow: TopToBottom }` inside a `Flickable`). Each tile: async image preview + truncated filename below. Active tile has accent border. Selected-for-slideshow tiles show a Nerd Font checkmark in the corner.
- Extensions: `.jpg`, `.jpeg`, `.png`, `.webp`, `.avif`

**Video / GIF section:**
- Same 3-row horizontal grid, single selection only (no slideshow)
- v1: Nerd Font play icon placeholder (no real thumbnail). v2: first-frame extraction via ffmpeg, cached to `~/.cache/pillbox/thumbs/`
- Extensions: `.mp4`, `.webm`, `.mkv`, `.mov`, `.gif`

**Empty states:** `"Set a directory above"` when no dir configured; `"No images found"` / `"No videos or GIFs found"` after a scan with no matches.

**Error feedback:** `"yin not started"` inline text when `WallpaperProcess.lastError` is set (yinctl non-zero exit).

#### WallpaperProcess data layer

- `setColor(hex)` — updates state, persists to Prefs, hides yin surface (color Rectangle takes over)
- `setImage(path)` / `setVideo(path)` — updates state, persists to Prefs, calls `yinctl --img <path>`
- `startSlideshow(files)` / `nextSlide()` / `stopSlideshow()` — interval `Timer` cycles files sequentially
- `setSlideshowInterval(secs)` — updates `slideshowTimer.interval`, persists to Prefs
- `scanDirectory(dir)` — runs `find <dir> -maxdepth 1 -type f`, sorts and splits output into `imageFiles`/`videoFiles` arrays by extension
- Startup restore: if `sourceType` is image/video and `wallpaperPath` non-empty, calls `yinctl --img <wallpaperPath>` on `Component.onCompleted`

**yin interaction:** yin handles image/video rendering. Solid color bypasses yin entirely. In color mode, yin keeps running with its last image underneath (invisible) — switching back to image/video reveals it without a new `yinctl` call.

**Pending (v2):**
- [ ] Real video thumbnails via ffmpeg (first frame, cached per file)
- [ ] `extractColors` toggle in Settings Appearance tab → Theme section
- [ ] Thumbnail cache cleanup for `~/.cache/pillbox/thumbs/`
- [ ] yin autostart via labwc autostart

---

### Media Player Panel 🔲

**File:** `module-panels/MediaPlayerPanel.qml` · **Keybind:** W-3

**Data sources needed:** `MprisProcess.activePlayer`

**Expected layout:**
- Album art (MPRIS metadata, if available)
- Track title + artist + album
- Playback controls: previous · play/pause · next
- Progress bar with current position and duration
- Volume control

**What still needs to be built:**
- `MediaPlayerPanel.qml` — panel UI consuming `MprisProcess.activePlayer`
- FIFO command `toggleMediaPlayer` added to `FifoListener` + `shell.qml`
- `PanelSurface` Loader case for `"mediaPlayer"`
- `PanelController.panelOrder` updated to include `"mediaPlayer"` at W-3 position
- labwc keybind W-3

(`MprisProcess` is already built and exposes everything needed.)
