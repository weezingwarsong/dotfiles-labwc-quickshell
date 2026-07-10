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

### NotificationServer

**File:** `root-processes/NotificationServer.qml` (planned — replaces mako)

Implements the D-Bus notification daemon directly via `Quickshell.Services.Notifications`. mako must be stopped (or removed from autostart) before this process claims the `org.freedesktop.Notifications` bus name.

**Owns:**
- `property var notifications` — `trackedNotifications` model from Quickshell's `NotificationServer`; used directly as Repeater model in the panel
- `property int countTotal` — total tracked (un-dismissed) notifications
- `property int countCritical` — count of urgency 2 (critical) notifications
- `property int _tsVersion` / `function getTimestamp(id)` — timestamp captured on arrival; reactive via `_tsVersion` dependency trick
- `signal newNotification(notif)` — emitted on each arrival; NotificationPill listens to trigger peek

**Per-notification fields (direct properties on each `Notification` object):**

| Field | Notes |
|---|---|
| `appName` | Sender app display name |
| `summary` | One-liner title |
| `body` | Optional body text (may be empty) |
| `urgency` | `NotificationUrgency.Low / Normal / Critical` |
| `image` | URL string — empty if none |
| `actions` | List of `NotificationAction` objects with `identifier`, `text`, `invoke()` |
| `id` | Unique uint — used as key for timestamp lookup |

**Methods:**
- `notification.dismiss()` — removes from `trackedNotifications`; counts update via `trackedNotificationsChanged`
- `notification.actions[i].invoke()` — sends D-Bus `ActionInvoked` reply to the originating app
- `root.clearAll()` — calls `dismiss()` on all tracked notifications
- `root.getTimestamp(id)` — returns `Date` captured at arrival time

**Counts** are maintained by `_recalc()`, triggered by `Connections { onTrackedNotificationsChanged }` and `onNotification`. Not derived from a native `.count` — `countCritical` requires iteration to filter by urgency.

**No persistence.** Notification list is in-memory only — cleared on quickshell restart. `keepOnReload: false`.

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

### Notification Pill ✅

**File:** `module-pills/NotificationPill.qml`

**What it does:** Shows a running count of un-dismissed notifications. Peeks for 7 s on each new arrival so the user notices without demanding persistent attention.

**Data sources (injected):** `NotificationServer`

**Stage 1 priority:**

| State | Priority | Notes |
|---|---|---|
| Any notification, within 7 s of arrival | `2` | Briefly beats TimePill (priority 1) during peek window |
| Idle (no peek active) | `0` | TimePill wins; pill is not visible |
| No notifications | `0` | Same — pill contributes nothing |

**Stage 2 reveal:** `shouldReveal = true` for 7 s after any `newNotification` signal, driven by a local `Timer`. Rapid arrivals extend the window. After the timer fires, pill hides until the next notification.

**Display:**
- When `countCritical > 0`: `"N | C"` — e.g. `"4 | 2"`
- When `countCritical === 0`: `"N"` — e.g. `"3"`
- Pill not visible when `countTotal === 0` (priority 0, TimePill wins)

**Background:** `Qt.darker(color11, 1.5)` (visible dark red) when `countCritical > 0` during peek; default `pillBgColor` otherwise. `criticalBgColor` (`Qt.darker 2.4`) is too dark to distinguish from `pillBgColor` at pill scale — the less-darkened variant is used instead.

**Note:** `PillWindow` reads `activePill.bgColor` if the property exists; falls back to `Style.pillBgColor` if undefined (all other pills).

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

**Behavior:** Keyboard-driven. Filter `TextInput` has focus immediately on open — user can type without clicking. List below filter narrows in real time (case-insensitive match on `appId + title`). Arrow keys move selection, Enter focuses window or launches app + closes panel, Escape closes without acting. Entire list is wrapped in a `Flickable` — any number of windows is scrollable without growing off-screen.

**Layout:**
1. Filter input (placeholder "Filter…")
2. Window list — each row: Nerd Font glyph (fixed width) · app name (25% width, elided) · window title (remaining, elided)
3. Separator (1px `panelDividerColor`) — visible only when filter text is non-empty and desktop apps match
4. Desktop app list — each row: app name; shown only when `filterInput.text !== ""`

**Desktop app list:**
- Data source: `DesktopEntries.applications` (Quickshell singleton from `import Quickshell`). `noDisplay: true` entries skipped.
- Filter: case-insensitive match on `entry.name`. Computed as `filteredApps` JS array (same pattern as `filteredWindows`).
- `selectedFlat` spans both lists: indices 0‥`filteredWindows.length-1` = windows; `filteredWindows.length`‥`filteredWindows.length+filteredApps.length-1` = apps. Arrow navigation and Enter work across both.
- Activation: `entry.execute()` then `dismissed()`.
- No icon column — `DesktopEntry.icon` is a bare XDG name string; `IconImage` resolves it via theme lookup but falls back to a broken path for icons absent from the current theme, producing console noise. Omitted in favour of plain text rows.

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

#### Theme section

A toggle `extractColors: bool` (default true) in the Appearance tab. **Implemented:** fires on every image wallpaper selection. Runs `matugen image --json hex --dry-run --source-color-index 0 <path>`, parses the `base16` JSON section (`base00`–`base0f`), writes to `Prefs.color0Override`–`color15Override`. `Style.qml` reads each slot with Nord fallback (`Prefs.color0Override !== "" ? Prefs.color0Override : "#2E3440"`). Toggle off clears all overrides, restoring Nord. Not triggered on slideshow advances — only explicit picks.

---

### Wallpaper Panel ✅

**File:** `module-panels/WallpaperPanel.qml` · **Keybind:** W-5

**Data sources (injected):** `WallpaperProcess`

Two tabs — `[ Color ] [ Media ]` — `PanelNavBar` as first row. Wallpaper is global (not per-workspace). Color extraction toggle lives in Settings → Appearance (implemented).

#### Color tab

24 preset muted solid-color swatches in a 6-column grid. Click applies immediately — no confirm. Active swatch has accent border. Tooltips show the color name. Solid color is rendered by a `Rectangle` inside `wallpaperWindow` (`PanelWindow` at `WlrLayer.Background` in `shell.qml`), visible only when `wallpaper.sourceType === "color"`.

Preset palette: 24 swatches ranging from very dark near-blacks to muted mid-tones (Nord Dark Blue `#3B4252`, Catppuccin Mocha `#1E1E2E`, Gruvbox Dark `#3C3836`, etc.). Full list in `WallpaperPanel.qml` `_swatches` property.

#### Media tab

**Directory input:** `TextInput` + `[Scan]` button → calls `wallpaperProcess.scanDirectory(dir)`. Persisted to `Prefs.wallpaperDir`.

**Images section:**
- `[ Single ] [ Slideshow ]` mode toggle
- Slideshow controls (visible in slideshow mode): `[–]` interval `[+]` stepper (±5 s, min 5 s; persisted to `Prefs.slideshowInterval`) + `[Apply]` button — starts slideshow with selected tiles (or all images if none selected)
- 3-column vertically-scrollable thumbnail grid (`Grid { columns: 3; flow: LeftToRight }` inside `Flickable { flickableDirection: VerticalFlick }`). Each tile: async image preview + truncated filename below. Active tile has accent border. Selected-for-slideshow tiles show a Nerd Font checkmark in the corner.
- Extensions: `.jpg`, `.jpeg`, `.png`, `.webp`, `.avif`, `.gif` — GIF handled by `AnimatedImage` (same element as static images; no branching needed)

**Video section:**
- Same 3-column vertical grid, single selection only (no slideshow)
- v1: Persists path/sourceType but video does not render — video rendering (phase 2) requires `import QtMultimedia` + `MediaPlayer` + `VideoOutput`. v2: first-frame thumbnail via ffmpeg, cached to `~/.cache/pillbox/thumbs/`
- Extensions: `.mp4`, `.webm`, `.mkv`, `.mov` (`.gif` moved to Images — handled by `AnimatedImage`)

**Empty states:** `"Set a directory above"` when no dir configured; `"No images found"` / `"No videos or GIFs found"` after a scan with no matches.

**Error feedback:** Inline text when `WallpaperProcess.lastError` is set — e.g. scan returned no files, or matugen extraction failed.

#### WallpaperProcess data layer

**File:** `root-processes/WallpaperProcess.qml`

No external daemons. All rendering handled by `wallpaperWindow` in `shell.qml` via reactive bindings to `WallpaperProcess` state.

Public API:
- `setColor(hex)` — updates `sourceType`/`currentColor`, persists to Prefs. `wallpaperWindow` Rectangle becomes visible automatically.
- `setImage(path)` — updates `sourceType`/`currentPath`, persists to Prefs, triggers `_maybeExtract()` if `Prefs.extractColors`. `wallpaperWindow` AnimatedImage updates via binding.
- `setVideo(path)` — updates `sourceType`/`currentPath`, persists to Prefs. Phase 2 placeholder — renders nothing until `MediaPlayer` is wired.
- `startSlideshow(files)` / `nextSlide()` / `stopSlideshow()` — interval `Timer` cycles files sequentially; `nextSlide` does NOT trigger matugen (intentional — avoids extraction every N seconds)
- `setSlideshowInterval(secs)` — updates `slideshowTimer.interval`, persists to Prefs
- `scanDirectory(dir)` — resets both file lists, then runs two separate `find` commands in parallel:
  - `_scanImgProc`: `find <dir> -maxdepth 1 -type f`, extension filter in JS (`.jpg .jpeg .png .webp .avif .gif`), no size cap, 200-item cap
  - `_scanVidProc`: same with `-size -100M`, extension filter (`.mp4 .webm .mkv .mov`), 200-item cap
- Startup restore: `Component.onCompleted` calls `scanDirectory` to populate grids. Wallpaper itself auto-restores — `AnimatedImage.source` binds to `wallpaper.currentPath` (which reads `Prefs.wallpaperPath` on init). No explicit restore call needed.

**Rendering surface:** `wallpaperWindow` in `shell.qml` — `PanelWindow` at `WlrLayer.Background` with `exclusiveZone: -1` covering the full screen. Two children, `visible` toggled by `sourceType`:
- `Rectangle` — `visible: wallpaper.sourceType === "color"`; `color: wallpaper.currentColor`
- `AnimatedImage` — `visible: wallpaper.sourceType === "image"`; `fillMode: PreserveAspectCrop`; `cache: false`

**Pending (v2):**
- [ ] Video rendering — `import QtMultimedia`, `MediaPlayer` + `VideoOutput`. Requires `qt6-multimedia` + GStreamer. Deferred until GPU/driver situation is stable.
- [ ] GIF rendering — should already work via `AnimatedImage`. Needs end-to-end test with an actual animated GIF file.
- [ ] Real video thumbnails — first frame via ffmpeg, cached to `~/.cache/pillbox/thumbs/`
- [ ] Multi-monitor — currently `Quickshell.screens[0]` only. Additive: wrap `wallpaperWindow` in a `Repeater` over `Quickshell.screens`.
- [ ] Visual layer makeover — current Fixed section in `Style.qml` uses hardcoded Nord semantic tokens. Future: dynamic mat3 / Material You color system mapped onto the base16 palette. All 16 slots already persisted via `Prefs.color0Override`–`color15Override`; Style.qml Variable section already reads them. The mapping logic and dynamic derivation of semantic tokens (not just raw palette) is the remaining work.

---

### Media Player Panel ✅

**File:** `module-panels/MediaPlayerPanel.qml` · **Keybind:** W-3

**Data sources (injected):** `MprisProcess` → `activePlayer`

---

#### No active player state

When `mprisProcess.activePlayer === null`, the panel shows a single centred line: `"No active player"` in `textMuted`. No other content rendered.

---

#### Layout (top to bottom)

```
PanelNavBar                        ← ‹ / › navigation, same as all panels
─────────────────────────────────
Album art                          ← square, fills panel width minus margins
─────────────────────────────────
[ ◀ ]  [ Artist — Title ~~~~~~~~ ]  [ ▶ ]
─────────────────────────────────
[ 🔊  volume  ]
```

---

#### Album art

A square `Rectangle` (side = panel content width = panel width − 2 × `panelMargin`). `Layout.fillWidth: true` + explicit `height: width` enforces the square.

- `Image` fills the Rectangle, `fillMode: Image.PreserveAspectCrop`, `clip: true`, `source: mprisProcess.activePlayer.trackArtUrl`
- `trackArtUrl` is typically a `file://` path or localhost `http://` URL. Set `Image.source` directly — Quickshell's Image handles both.
- When `trackArtUrl` is empty or the image fails to load (`Image.status !== Image.Ready`): show a centred Nerd Font music glyph (`String.fromCodePoint(0xf001)`) in `textFaint` over `surfaceLowColor` background. Same square dimensions.

Corner radius: `radLg` on the Rectangle (matches PanelCard).

---

#### Controls row

A single `RowLayout` below the album art.

**Previous button `[◀]`** — `IconButton`, glyph `String.fromCodePoint(0xf048)` (nf-fa-step-backward). `onClicked: mprisProcess.activePlayer.previous()`. `enabled: mprisProcess.activePlayer.canGoPrevious` — dimmed and non-interactive when the player doesn't support it (e.g. radio streams).

**Centre — track info + play/pause:**

A `Rectangle` with `Layout.fillWidth: true`, height `Style.buttonHeight`. Clips overflowing text. On click: `mprisProcess.activePlayer.togglePlaying()`. `enabled: mprisProcess.activePlayer.canTogglePlaying`.

Inside: a `Text` element that scrolls left continuously when the content overflows. Content: `artist + " — " + title` (em dash separator) when `trackArtist` is non-empty, otherwise just `title`. `trackArtist` may contain multiple artists as a single string (players separate them with `", "`, `" & "`, or `";"`) — display as-is, no parsing.

Scroll behavior: when `implicitWidth > parent.width`, a `NumberAnimation` on `x` runs from `0` to `-(implicitWidth - parent.width)` then snaps back to `0`. Pauses 1.5 s at each end before animating. Resets and restarts whenever track changes. When content fits, no animation — text is static and left-aligned.

Font: `Style.fontMono`, `Style.fontSizeBody`, `Style.textNormal`. HoverHandler tints the background `surfaceLowColor` to hint clickability.

**Next button `[▶]`** — `IconButton`, glyph `String.fromCodePoint(0xf051)` (nf-fa-step-forward). `onClicked: mprisProcess.activePlayer.next()`. `enabled: mprisProcess.activePlayer.canGoNext`.

---

#### Volume button

A `PanelButton` below the controls row, `Layout.fillWidth: true`.

- **Label:** two states only — no glyphs.
  - **Muted** (`_muted === true`): label `"M"`, color `Style.textMuted`.
  - **Not muted**: label `Math.round(activePlayer.volume * 100) + "%"`, color `Style.textSecondary` (default button text).
- **Click:** toggle mute. MPRIS has no native mute; simulate by storing the pre-mute volume in a local `property real _savedVolume` and toggling between `activePlayer.volume = 0` and restoring `_savedVolume`.
- **Scroll:** `WheelHandler` on the button. `angleDelta.y > 0` → `activePlayer.volume = Math.min(1.0, activePlayer.volume + 0.05)`. `angleDelta.y < 0` → `activePlayer.volume = Math.max(0.0, activePlayer.volume - 0.05)`. Same pattern as TimerWidget's duration scroll.

> **Fix candidate (deferred):** `MprisPlayer.volume` is read/write per the MPRIS spec but some players ignore writes (Spotify, browser-based players). If volume control proves unreliable in practice, the volume button will be removed and system volume will live in the Control Panel only.

---

#### MprisPlayer properties used

| Property / Method | Used for |
|---|---|
| `activePlayer.trackArtUrl` | Album art source |
| `activePlayer.trackTitle` | Track name in scrolling text |
| `activePlayer.trackArtist` | Artist name in scrolling text |
| `activePlayer.togglePlaying()` | Centre text click |
| `activePlayer.canTogglePlaying` | Enables/disables centre click |
| `activePlayer.previous()` | ◀ button |
| `activePlayer.canGoPrevious` | Enables/disables ◀ |
| `activePlayer.next()` | ▶ button |
| `activePlayer.canGoNext` | Enables/disables ▶ |
| `activePlayer.volume` | Volume button read/write |

No progress bar. No track duration. No elapsed time.

---

#### Album art click — focus player window

Clicking the album art (or music glyph placeholder) calls `wlrctl toplevel focus app_id:<desktopEntry>`, where `desktopEntry` is the standard MPRIS property on `MprisPlayer`. Raises and focuses the player window. A short-lived `Process` from `Quickshell.Io` handles the wlrctl call.

#### Built — wiring checklist

- [x] `MediaPlayerPanel.qml` — panel UI
- [x] `FifoListener.qml` — `toggleMediaPlayerRequested` signal + `"toggleMediaPlayer"` dispatch
- [x] `shell.qml` — `onToggleMediaPlayerRequested` → `panelController.toggle("mediaPlayer")`
- [x] `PanelSurface.qml` — `"mediaPlayer"` Loader case + `mprisProcess` injection
- [x] `PanelController.panelOrder` — `["calendar", "mediaPlayer", "settings", "wallpaper"]`
- [x] `module-panels/qmldir` — `MediaPlayerPanel 1.0` (pre-registered as stub)
- [x] labwc `rc.xml` — W-3 → `toggleMediaPlayer`

---

### Notification Panel ✅

**File:** `module-panels/NotificationPanel.qml` · **Keybind:** W-6

**Data sources (injected):** `NotificationServer`

**Layout (top to bottom):**

```
PanelNavBar                         ← ‹ / › navigation
─────────────────────────────────
[ Clear all ]                       ← right-aligned button; hidden when list is empty
─────────────────────────────────
Notification cards (scrollable)     ← newest first, Flickable wrapper
─────────────────────────────────
"No notifications" empty state      ← shown when list is empty
─────────────────────────────────
[ 🔔 ] [ 💬 ] [ 🎵 ]              ← systray icon row (right-aligned); hidden when empty
```

**Notification card:**

Each card is a `Rectangle` with padding on all sides. Background color communicates urgency:
- Urgency 0 (low): `surfaceLowColor`
- Urgency 1 (normal): `surfaceMidColor`
- Urgency 2 (critical): `criticalBgColor` at low opacity (tinted, not solid)

**Dismiss:** Right-click anywhere on the card → `notificationServer.dismiss(id)`. `[×]` button (top-right) does the same — redundant, for discoverability. Both paths call the same dismiss.

**Left-click** on the card body is intentionally not wired: in Qt 6, a card-level `TapHandler` fires even when a child button (`[⋮]`, action buttons) is clicked, causing accidental dismissal. Right-click + `[×]` are the primary dismiss paths.

**Card layout — two columns:**

```
[ img ]  timestamp                      [ × ]
         Summary
         Body text
         [ Action 1 ] [ Action 2 ] [ ⋮ ]
         [ Action 3 ] [ Action 4 ]        ← expanded row, hidden by default
```

- **Left column:** square image thumbnail (`fillMode: PreserveAspectCrop`, `clip: true`). Hidden when `notification.image` is empty — right column spans full width in that case.
- **Right column** (top to bottom):
  1. **Header row** — `timestamp` right-aligned (`textMuted`, mono, e.g. `"14:07"`) · `[×]` dismiss button far-right
  2. **Summary** — `summary` text (`textNormal`, slightly larger than body size)
  3. **Body** — `body` text (`textMuted`, body size). Hidden when empty. Multiline — no truncation.
  4. **Primary action row** — up to 2 `PanelButton`s, then `[⋮]` icon button if more actions exist. Hidden when `actions` is empty.
  5. **Overflow action row** — remaining actions (max 2 more, so up to 4 total labeled actions). Hidden until `[⋮]` is tapped; `[⋮]` toggles it. Hidden entirely when ≤ 2 actions.

**Action button labels:** elided with `"…"` if they overflow the button width. Full label shown in a `ToolTip` on hover.

**Action invocation:** clicking any action button calls `notificationServer.invokeAction(id, actionId)` then `notificationServer.dismiss(id)`.

**Scrollable list:** `Flickable` with `contentHeight` = sum of card heights + spacing. `clip: true`. The panel has a max height cap (same `_maxHeight` as all panels in `PanelSurface`). Overflow scrolls rather than extending off-screen.

Cards are separated by `Style.panelMargin / 2` spacing.

**Empty state:** When `notificationServer.countTotal === 0`, show a single centred line `"No notifications"` in `textMuted`.

**Clear all button:** A `PanelButton` with `variant: "critical"` (to stand out), label `"Clear all"`. Calls `notificationServer.clearAll()`. Hidden when list is empty.

**Systray footer (`SysTrayBar.qml`):**

A right-aligned `RowLayout` of 24×24 icon buttons from `SystemTray.items` (the `Quickshell.Services.SystemTray` singleton model). Separated from the cards by a 1px `panelBorderColor` divider. Both the divider and the bar collapse to `height: 0` when no apps are registered, so the Flickable fills the full panel height. Left-click → `activate()`, right-click → `secondaryActivate()`. `IconImage` (`Quickshell.Widgets`) resolves XDG theme icon names.

**Quickshell SystemTray API notes:**
- `SystemTray` is a singleton namespace — `SystemTray { id: x }` is not creatable.
- `SystemTray.items.count` returns `undefined` (the underlying `ObjectModel` type does not expose `.count` in QML). Use `Repeater.count` instead — it is always a valid reactive `int`.

#### Wiring checklist

- [x] `NotificationServer.qml` — D-Bus daemon, notification list, counts
- [x] `NotificationPanel.qml` — panel UI
- [x] `NotificationPill.qml` — pill display
- [x] `FifoListener.qml` — `toggleNotificationsRequested` signal + `"toggleNotifications"` dispatch
- [x] `shell.qml` — instantiate `NotificationServer`, `onToggleNotificationsRequested` → `panelController.toggle("notifications")`; inject `notificationServer` into `PanelSurface` and `NotificationPill`
- [x] `PanelSurface.qml` — `"notifications"` Loader case + `notificationServer` injection
- [x] `PanelController.panelOrder` — `["calendar", "mediaPlayer", "notifications", "settings", "wallpaper"]`
- [x] `module-panels/qmldir` — register `NotificationPanel`, `SysTrayBar`
- [x] `module-pills/qmldir` — register `NotificationPill`
- [x] `PillController.qml` — `notificationPill` property added; priority 2 peek slot
- [x] `PillWindow.qml` — reads `activePill.bgColor` for critical background
- [x] labwc `rc.xml` — W-6 → `toggleNotifications`
- [x] mako removed from runtime (`killall mako`); remove from `labwc/autostart`
