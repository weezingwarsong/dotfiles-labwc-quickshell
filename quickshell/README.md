# Pillbox

Pillbox is a Quickshell-based desktop shell — a bar/overlay system in the spirit of Waybar or Noctalia, but built around two distinct visual primitives: Pills and Panels.

### Pill
A small rounded rectangle anchored at the top-center of the screen. Hidden by default. **Smart and context-aware** — it reveals itself automatically when there is something relevant to show, and retreats back into hiding when there is not. It can also be surfaced explicitly by the user.

**Implementation:**
- A single `PanelWindow` anchored top-center of the primary screen. Width is `screen.width * 0.10`, height is `24px`.
- On multi-screen setups, the pill appears on the primary screen only. Primary is defined as the first entry in `Quickshell.screens`, with a config option to override by index.
- All pills share this one window. **Only one pill is ever active at a time.** The window acts as a dumb container — it renders whatever the currently active pill exposes as `displayText` via a `Loader`.
- A two-stage priority system governs which pill shows and when. **Stage 1 — winner:** each pill exposes `priority: int` and `shouldReveal: bool`; the highest-priority pill wins. Priority order (highest → lowest): WindowPill → WorkspacePill → MprisPill → TimePill. **Stage 2 — show/hide:** three independent triggers — hover, W-1 latch, or content-driven reveal. Stage 1 and Stage 2 are independent: the winner is always pre-computed so the display is instant when Stage 2 opens the gate.

### Panel
A larger rounded rectangle that appears below the Pill. **Dumb and passive** — it has no opinion about when to appear. It only opens when the user deliberately calls it, and only closes when the user deliberately dismisses it.

**Only one panel is ever shown at a time.** If a panel is already open and the user summons a different panel, the current panel dismisses immediately and the new one takes its place. Last call wins.

**Navigation:** Panels are ordered in a conceptual row (Calendar → Media Player → Settings → …), matching their W-2 / W-3 / W-4 / … keybind positions. While any panel is open, left/right arrow keys cycle through the row, and two floating `‹` `›` buttons at the top-right of the panel surface do the same. Dismissing is symmetric: ESC, a second press of the same keybind, or clicking anywhere outside the panel all close it. The window switcher is excluded from the row by design — it has its own dedicated behaviour.

---

## Contents

1. [Pillbox](#pillbox) — what it is; pills and panels defined
2. [Target & Philosophy](#target--philosophy) — labwc-only, data-first, one source of truth
3. [Implementation](#implementation) — built modules: processes, reusable elements, pills, panels
4. [Planning Board](PlanningBoard.md) — design specs for all modules (done and planned)
5. [To-Do](#to-do)
6. [Directory Tree](#directory-tree)

---

## Target & Philosophy

### Target
**labwc only.** No Hyprland, Niri, or other compositor support. Data comes from standard Wayland protocols and Quickshell's built-in backends — no compositor-proprietary IPC.

### Philosophy
Functionality before visuals. Every pill and panel must have its data plumbing and logic fully working before any visual layer is added. If visuals break, they can be purged and rewritten without touching the data layer.

The build order for each new module is:
1. Define what it does and how to achieve it (Draft Board)
2. Write the process / data layer — validate via `console.log`
3. Wire the visual layer through `Style.qml`

### Rule: One Source of Truth
No pill or panel may fetch its own data. All data flows from `root-processes/` down. This makes the data layer independently testable and prevents duplicated IPC connections.

---

## Implementation

### Processes

#### FifoListener

**File:** `root-processes/FifoListener.qml`

Starts with Pillbox, dies with Pillbox. Tails a named pipe at `~/.local/share/pillbox/pillbox.fifo` using a `Process`. Any external tool — labwc keybinds, shell scripts, other processes — can send commands to Pillbox by writing a string to that pipe. `FifoListener` reads each line, pattern-matches the command, and emits the appropriate signal for the rest of Pillbox to react to.

This is the general command bus for all external input into Pillbox.

**Known commands:**

| Command | Effect |
|---|---|
| `showTime` | Latches the pill on (W-1 toggle); a second press dismisses |
| `refreshCalendar` | Tells CalendarProcess to fetch immediately outside its normal cycle |
| `toggleCalendar` | Opens or dismisses the calendar panel |
| `toggleWindowSwitcher` | Opens or dismisses the window switcher panel (W-Tab) |
| `toggleSettings` | Opens or dismisses the settings panel |
| `setTimer:N` | Tells TimerProcess to set a countdown for N seconds |
| `startTimer` | Tells TimerProcess to start or resume the countdown |
| `pauseTimer` | Tells TimerProcess to pause the countdown |
| `resetTimer` | Tells TimerProcess to reset the countdown |
| `startStopwatch` | Tells TimerProcess to start stopwatch mode |
| `stopStopwatch` | Tells TimerProcess to stop the stopwatch |
| `resetStopwatch` | Tells TimerProcess to reset the stopwatch |

---

#### ClockProcess

**File:** `root-processes/ClockProcess.qml`

A `QtQuick.Timer` fires every second and updates the exposed time properties. All time-aware pills bind to this single source — nothing reads `new Date()` on its own.

**Exposes:**
- `displayTime` — formatted string `"HH:mm"` for display in the pill
- `displayTimeFull` — formatted string `"HH:mm:ss"` for debug/logging
- `now` — raw JavaScript `Date` object, used by TimePill to compute time-to-next-event

---

#### CalendarProcess

**File:** `root-processes/CalendarProcess.qml`

Fetches upcoming calendar events from Google Calendar via `gcal-fetch` (`helper/calendar/gcal_fetch.py`, symlinked to `~/.local/bin/gcal-fetch`). Exposes pre-computed views so panels never re-filter the raw list.

**Fetch behaviour:**
- Waits 10 seconds on startup before the first fetch — lets the network settle
- Fetches automatically every 5 minutes after the first fetch
- Fetches immediately on receiving the `refreshCalendar` command from `FifoListener`
- On fetch failure (no network, expired token), retains the last known data silently — no crash, no clear
- Network errors are logged to `/tmp/pillbox-google.log` with timestamps
- Auth errors (expired token) send a `notify-send` notification with a "Re-authenticate" action button that opens a terminal running `gcal-fetch --auth`

**`gcal-fetch` fetch window:** 3 months back to 24 months ahead, max 250 events. The wide window lets the calendar panel navigate months client-side without re-fetching.

**Exposes:**
- `events` — all events, raw from `gcal-fetch`
- `nextEvent` — first event with `start >= now` (filters out past events)
- `todayEvents` — events whose start date is today
- `weekEvents` — events whose start date is within the next 7 days
- `eventsByDate` — `"YYYY-MM-DD" → [events]` map for month view dot indicators
- `lastUpdated` — timestamp of the last successful fetch

**All-day events:** `start` and `end` are date-only strings (`"2026-07-04"`). Timed events use ISO 8601 with timezone (`"2026-07-04T14:00:00+08:00"`). `allDay: bool` distinguishes them.

---

#### TasksProcess

**File:** `root-processes/TasksProcess.qml`

Fetches tasks from Google Tasks via `gtask-fetch` (`helper/tasks/gtask_fetch.py`, symlinked to `~/.local/bin/gtask-fetch`). Follows the same shape as `CalendarProcess`.

**Fetch behaviour:**
- Same 10-second startup delay and 5-minute repeat as `CalendarProcess`
- Fetches all incomplete tasks and completed tasks from the last 30 days
- Network and auth errors handled identically to `CalendarProcess`

**`gtask-fetch` output shape:**
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
`due` is `null` if no due date is set. Tasks without a due date are included in `tasks` but excluded from all date-keyed views.

**Exposes:**
- `tasks` — all tasks, raw from `gtask-fetch`
- `todayTasks` — tasks due today
- `weekTasks` — tasks due within the next 7 days
- `overdueTasks` — incomplete tasks past their due date
- `tasksByDate` — `"YYYY-MM-DD" → [tasks]` map for date-based display
- `lastUpdated` — timestamp of the last successful fetch

---

#### TimerProcess

**File:** `root-processes/TimerProcess.qml`

Owns all timer and stopwatch state. No pill or panel holds timer state directly — they all read from here. `TimerWidget` calls these methods directly; `FifoListener` calls the same methods in response to keybind commands.

**Modes:**
- *Countdown* — counts down from a user-set duration to zero
- *Countup* — counts up from zero indefinitely

**Exposes:**
- `mode` — `"idle"` | `"timer"` | `"stopwatch"`
- `active` — bool, true while ticking
- `duration` — total seconds set (countdown); default 90 (1m 30s)
- `remaining` — seconds left (countdown only)
- `elapsed` — seconds passed (countup only)
- `displayText` — `"HH:MM:SS"` string ready for direct display (e.g. `"00:01:30"`)

**Methods (called directly by `TimerWidget`):**
- `setTimer(seconds)` — set countdown duration; updates `duration` and `remaining`, resets display
- `startTimer()` — start or resume countdown
- `pauseTimer()` — pause countdown
- `resetTimer()` — stop and restore `remaining` to `duration`
- `startStopwatch()` — switch to countup mode and begin from zero
- `stopStopwatch()` — pause countup
- `resetStopwatch()` — stop and return `elapsed` to zero

| FIFO Command | Effect |
|---|---|
| `setTimer:300` | Set a countdown for N seconds |
| `startTimer` | Start or resume the countdown |
| `pauseTimer` | Pause the countdown |
| `resetTimer` | Reset countdown to original duration |
| `startStopwatch` | Start countup mode |
| `stopStopwatch` | Stop the countup |
| `resetStopwatch` | Reset countup to zero |

---

#### WeatherProcess

**File:** `root-processes/WeatherProcess.qml`

Fetches weather data via `weather-fetch` (`helper/weather/weather_fetch.py`, symlinked to `~/.local/bin/weather-fetch`). Uses Open-Meteo API (no API key required). Location is determined via ipapi.co (result cached for 24 hours).

**Fetch behaviour:**
- Same 10-second startup delay as other processes
- Refreshes every 30 minutes

**Exposes:**
- `current` — object: `{ icon, temp, condition, high, low }`
- `forecast` — array of 7 objects: `{ date, icon, condition, high, low }`

Icons are Nerd Font codepoints (strings), rendered via `String.fromCharCode(parseInt(icon, 16))`.

---

#### WorkspaceProcess

**File:** `root-processes/WorkspaceProcess.qml`

Pure QML `Item` — no subprocess. Binds to `Quickshell.WindowManager`. An `Instantiator` over `WindowManager.windowsets` creates one `Connections` watcher per `Windowset`. When any `Windowset.active` flips true, `current` updates and `workspaceChanged` fires.

**Exposes:**
- `current` — the active `Windowset` object (has `.name`, `.active`, `.activate()`)
- `list` — ordered array of all workspace names
- `currentIndex` — index of `current` in `WindowManager.windowsets`
- `signal workspaceChanged(var workspace)` — emitted on every switch

---

#### ToplevelProcess ✓

**File:** `root-processes/ToplevelProcess.qml`

Pure QML `Item` — no subprocess. Binds directly to `Quickshell.Wayland.ToplevelManager`, which implements the `zwlr-foreign-toplevel-management-v1` Wayland protocol. No `Instantiator` needed for focus tracking — `ToplevelManager.activeToplevel` provides that natively.

A lightweight `Instantiator` is kept for add/remove logging only; it does no state management.

**Exposes:**
- `windows` — `ToplevelManager.toplevels` (`ObjectModel<Toplevel>`). Iterate in JS via `.values`. Each `Toplevel` has `.appId`, `.title`, `.activated`, `.activate()`, `.close()`.
- `focused` — alias for `ToplevelManager.activeToplevel`. The compositor's single currently active window, or `null`. Updates reactively via the native `onActiveToplevelChanged` signal.

---

#### MprisProcess ✓

**File:** `root-processes/MprisProcess.qml`

Pure QML `Item` — no subprocess. Binds to `Quickshell.Services.Mpris.Mpris.players` (`ObjectModel<MprisPlayer>`). An `Instantiator` creates one `Connections` watcher per player, listening to `onPlaybackStateChanged` and `onTrackChanged`.

Unlike `ToplevelProcess`, there is no native "active player" equivalent — `_selectPlayer()` runs on every state change and picks the most relevant player: **Playing > Paused > first available**.

**Exposes:**
- `players` — `Mpris.players` (`ObjectModel<MprisPlayer>`). Iterate in JS via `.values`. Each `MprisPlayer` has `.playbackState` (`MprisPlaybackState.Playing/Paused/Stopped`), `.trackTitle`, `.trackArtist`, `.trackAlbum`, `.isPlaying`, `.togglePlaying()`, `.next()`, `.previous()`.
- `activePlayer` — the currently selected `MprisPlayer`, or `null` if no players are connected. Re-evaluated on every player state or track change.
- `signal playerUpdated(var player)` — emitted on any playback state change or track change. `MprisPill` listens to this to trigger its peek.

---

### Reusable Elements

Visual UI building blocks shared across all panels. Full specs in **[components.md](components.md)**.

| Component | Purpose |
|---|---|
| `PanelButton` ✓ | Labelled action button; 3 variants (default / accent / critical) |
| `PanelCard` ✓ | Raised section container (`surfaceLowColor` bg, `radLg` corners) |
| `PanelDivider` ✓ | Full-width 1px horizontal rule |
| `SectionLabel` ✓ | Small all-caps tracking label for panel sections |
| `StatusDot` ✓ | 8px filled circle; green = active, red = inactive |
| `TogglePair` ✓ | Two adjacent exclusive-select buttons (e.g. Auto / Manual) |

All tokens come from `Style.qml`; user-adjustable values come through `Prefs.qml`.

#### PillController ✓

**File:** `module-reusable-elements/PillController.qml`

The single source of truth for all pill show/hide decisions. A `QtObject` — no visuals, pure logic. Every input that could influence pill visibility flows into `PillController`; nothing else makes show/hide decisions.

*Stage 1 — Winner:* Which pill has the most relevant content right now. Pre-computed so the display is instant on reveal. Priority order (highest → lowest): WindowPill → WorkspacePill → MprisPill → TimePill.

Each pill exposes `priority: int` (Stage 1) and `shouldReveal: bool` (Stage 2 content signal). `PillController` reads only these — never pill-specific properties:
- `WindowPill` — `priority: 200` while switcher open, `0` otherwise
- `WorkspacePill` — `priority: 100` for 1.5s after switch, `0` otherwise
- `MprisPill` — `priority: 5` while actively playing, `0` paused/idle
- `TimePill` — `priority: 10` when calendar imminent or timer active, `1` always (permanent fallback)

*Stage 2 — Show/hide:* Three independent triggers:
1. **Hover** — cursor in `HoverZone`. Always works, never suppressible.
2. **Latch** — W-1 keybind via FIFO. Persistent toggle: first press locks the pill on indefinitely, second press dismisses it.
3. **Content-driven** — `winner.shouldReveal` is true. Blocked by `_userDismissed` so the user can silence an active condition. `_userDismissed` auto-clears when the condition ends naturally.

Note: `MprisPill.shouldReveal` (the 3-second peek on state change) drives Stage 2's content-driven trigger independently of `priority`. While music plays with no state changes, `shouldReveal` is false — the pill won't auto-reveal — but MPRIS still holds the winner slot, so hover and latch surface it.

**Inputs:** `hovered: bool` (from HoverZone), each pill object (reads their `priority` / `shouldReveal`)<br>
**Outputs:** `winner`, `shouldShow: bool`, `activePill` (`winner` if `shouldShow`, else `null`)

---

#### PillWindow ✓

**File:** `module-reusable-elements/PillWindow.qml`

A `PanelWindow` anchored top-center on `Quickshell.screens[0]`. `exclusiveZone: 0` — overlays windows, reserves no screen space. `mask: Region {}` — fully pointer-transparent so `HoverZone` always receives the cursor beneath it.

- `implicitWidth: (contentLoader.item ? contentLoader.item.implicitWidth : 0) + 40`, `implicitHeight: 24` — width is content-driven; the +40 accounts for 20px padding each side. No `anchors.left`/`anchors.right` — layer-shell centers automatically when only `anchors.top` is set.
- `margins.top: Screen.height * 0.01` gap from screen edge
- `Loader { id: contentLoader; sourceComponent: activePill.visualComponent; width: item ? item.implicitWidth : 0 }` — each pill owns its visual and declares its natural `implicitWidth`; `PillWindow` binds to it.
- Completely dumb — no logic, no opinions.

---

#### HoverZone ✓

**File:** `module-reusable-elements/HoverZone.qml`

An always-present transparent `PanelWindow`, 8px tall, anchored top-center. Never hides — must always be present to detect cursor entry even when the pill is hidden. Exposes `hovered: bool` with a 120ms leave debounce to prevent edge jitter. Feeds into `PillController.hovered` only.

---

#### PanelController ✓

**File:** `module-reusable-elements/PanelController.qml`

Manages which panel is currently shown. Enforces one-at-a-time: `toggle(panelId)` opens a panel or dismisses it; summoning a different panel replaces the current one immediately.

**Panel order:** An ordered list `panelOrder: ["calendar", "settings"]` defines the navigation sequence (window switcher excluded by design; future panels appended as built). `navigate(direction)` steps through this list — `+1` = next, `-1` = prev — with wrapping. Both the floating nav buttons and left/right arrow keys call this method.

---

#### PanelSurface ✓

**File:** `module-reusable-elements/PanelSurface.qml`

A separate `PanelWindow` surface centered horizontally, top edge at `Screen.width * 0.10` from screen top. Width `Screen.width * 0.15`, height content-driven. Receives `activePanel` and `shouldShow` from `PanelController`, loads the correct panel via `Loader`. Geometry authority — individual panels are content only.

**Keyboard focus:** `WlrKeyboardFocus.Exclusive` for all panels (including settings), same as window switcher. This blocks compositor keybinds while a panel is open; the click-outside dismiss layer ensures the user always has a fast exit path.

**ESC to dismiss:** `Keys.onEscapePressed` on the `Loader` (which has `focus: true`) emits `dismissRequested()` → `shell.qml` calls `panelController.toggle(activePanel)`.

**Keyboard navigation:** `Keys.onLeftPressed` / `Keys.onRightPressed` on the `Loader` call `panelController.navigate(-1/+1)`. TextInputs inside panels consume their own arrow keys first (Qt's normal event propagation order), so text editing is unaffected.

**Floating nav buttons:** Two `‹` `›` `PanelButton`s anchored at the top-right of the PanelSurface window, above the panel content rectangle. Clicking calls `panelController.navigate(-1/+1)`.

**Click-outside dismiss:** A fullscreen transparent `PanelWindow` (`WlrLayer.Overlay`, rendered below PanelSurface, visible whenever any navigable panel is open) lives in `shell.qml`. A full-coverage `MouseArea` on it calls `panelController.toggle(activePanel)`. Clicks that land on the panel itself do not reach this layer — the panel surface sits on top.

---

#### Style.qml ✓

**File:** `Style.qml` (root, `pragma Singleton`)

All visual values go through `Style.qml`. Registered in the root `qmldir` and re-exported via each subdirectory's `qmldir` so all modules can access it without an explicit module path.

Three sections:
- **Variable** — raw palette: 16-color terminal palette (`color0`–`color15`) seeded with Nord; 2 font-family constants; `transparent`. Intended to be swapped from wallpaper extraction (pywal/matugen) in a future phase.
- **Fixed** — semantic mappings: `pillBgColor`, `textPrimary`, `textSecondary`, `accentBgColor`, `surfaceLowColor`, `textCritical`, `textWeekend`, `dotIndicator`, etc. All components read Fixed tokens — never Variable directly.
- **Prefs-derived** — tokens that update live when the user changes a preference: `fontSizePill/Body/Heading/Subtle`, `radSm/Md/Lg`, `borderWidth`, `elementBorderWidth`. Derived from `Prefs.qml`.

**`Prefs.qml`** (`pragma Singleton`) — companion file that owns the `QtCore.Settings` block. Exposes 7 user-adjustable properties (`fontMono`, `fontNerd`, `fontSizePill`, `fontSizeBase`, `radiusScale`, `borderWidth`, `elementBorderWidth`) with setters the Appearance tab calls directly. Changes propagate to `Style` and then to every component on the same frame.

Fonts: **JetBrains Mono Nerd Font** (`ttf-jetbrains-mono-nerd`) — monospace text and Nerd Font glyphs. **Sarasa Mono SC** (`ttf-sarasa-gothic`) — CJK fallback, handled transparently by Qt via fontconfig. All text items use `font.family: Style.fontMono`.

---

### Pills

#### TimePill ✓

**File:** `module-pills/TimePill.qml`

Reads from `ClockProcess`, `CalendarProcess`, `TimerProcess` — all injected by `shell.qml`. Exposes `displayText` (timer/stopwatch text when active, otherwise current time), `shouldShow` (true when calendar event ≤ 10 min away or timer is active), and `visualComponent` (a simple `Text` element).

#### WorkspacePill ✓

**File:** `module-pills/WorkspacePill.qml`

Reads from `WorkspaceProcess` (injected). `shouldShow` is true for 1.5 seconds after each `workspaceChanged`; a local `Timer` resets on rapid switches. `visualComponent` shows the workspace name on the left and Nerd Font radiobox glyphs (one per workspace, active/inactive) on the right.

#### WindowPill ✓

**File:** `module-pills/WindowPill.qml`

Reads from `ToplevelProcess` (injected). `shouldShow` is set externally by `shell.qml` — true while the window switcher panel is open, false otherwise. This means the pill is visible during active switching, not as a passive always-on indicator.

`visualComponent` shows a Nerd Font app glyph alongside the focused window's `appId`. The glyph is resolved via `_glyphFor(appId)` — same lookup table as `WindowSwitcherPanel`.

---

#### MprisPill ✓

**File:** `module-pills/MprisPill.qml`

Reads from `MprisProcess` (injected). Two properties drive its behaviour:
- `priority: 5` while `playbackState === Playing`, `0` otherwise. Playing music holds the winner slot over TimePill; paused drops below it.
- `shouldReveal: bool` — true for 3 seconds after any `playerUpdated` event (track change or playback state change). This is the Stage 2 content-driven peek signal. `_peeking` local flag driven by a `Timer`.

`visualComponent` shows a playback state glyph (`String.fromCodePoint(0xf04b/0xf04c/0xf04d)`) via `fontNerd`, and the track title via `font.families: [fontMono, fontCJK]` to support CJK track names. Title elided right.

---

### Panels

#### CalendarPanel ✓

**File:** `module-panels/CalendarPanel.qml`

Reads from `CalendarProcess`, `TasksProcess`, `ClockProcess`, `WeatherProcess`, `TimerProcess` — all injected via `PanelSurface.onLoaded`. Three views navigated by explicit buttons: **glance** (date, weather, today events, month grid, today tasks, footer nav buttons), **expanded** (7-day schedule, 7-day tasks, 7-day forecast), and **timer** (rendered by `TimerWidget`, injected with `timerProcess`). `TimerWidget` calls `TimerProcess` methods directly — no FIFO round-trip.

#### WindowSwitcherPanel ✓

**File:** `module-panels/WindowSwitcherPanel.qml`

Reads from `ToplevelProcess` (injected via `PanelSurface.onLoaded`). A `FocusScope` — keyboard events go directly to `filterInput` via `Qt.callLater(filterInput.forceActiveFocus)` on load.

**Filter:** `filteredWindows` is a computed JS array built by iterating `toplevelProcess.windows.values`, case-insensitive matching against `appId + " " + title`. Resets selection to index 0 on text change.

**Selection:** `selectedFlat: int` tracks the keyboard cursor. Arrow keys move it; hovering a row syncs it. Selected row gets `accentBgColor` background. Hovered-but-not-selected row gets `surfaceLowColor`.

**Activation:** `filteredWindows[selectedFlat].activate()` — Quickshell's native `ToplevelManager` call, no subprocess. Emits `dismissed()` signal after activation. Escape also emits `dismissed()`. `PanelSurface` forwards `dismissed()` as `dismissRequested()` to `shell.qml`, which calls `panelController.toggle("windowSwitcher")`.

---

## Planning Board

Full design specs for all modules (implemented and planned) live in **[PlanningBoard.md](PlanningBoard.md)**.

---

## To-Do

Full specs for all planned modules live in **[PlanningBoard.md](PlanningBoard.md)**. Summary:

- [ ] **Media Player Panel** (W-3) — MPRIS playback controls, album art, progress bar, volume.
- [x] **Wallpaper Panel** (W-5) — solid color picker + image/video thumbnail browser. External renderer: yin. See [PlanningBoard.md § Wallpaper Panel](PlanningBoard.md#wallpaper-panel).
  - [ ] Further testing and touch-up required.
  - [ ] Video tile thumbnails (v1 shows placeholder icon; v2: ffmpeg first-frame extraction).
  - [ ] `extractColors` toggle in Settings Appearance tab (Theme section).
- [ ] **Theme color extraction** — global toggle in Appearance tab of Settings. Fires on every wallpaper change. Extractor TBD. Blocked on wallpaper panel stabilizing.
- [ ] **Style.qml cleanup** — remove remaining backward-compat aliases (`fontContentSize`, `radLight`, `textLight`, `textSubtle`, etc.). See settings.md build order step 6.

---

## Directory Tree

```
quickshell/
├── module-panels/
│   ├── CalendarPanel.qml         ✓ implemented
│   ├── MediaPlayerPanel.qml
│   ├── SettingsPanel.qml         ✓ services + appearance tabs
│   ├── TimerWidget.qml           ✓ implemented
│   ├── WallpaperPanel.qml         ✓ implemented (testing + touch-up pending)
│   ├── WindowSwitcherPanel.qml   ✓ implemented
│   └── qmldir
├── module-pills/
│   ├── MprisPill.qml             ✓ implemented
│   ├── ScreenrecPill.qml
│   ├── TimePill.qml              ✓ implemented
│   ├── WindowPill.qml            ✓ implemented
│   ├── WorkspacePill.qml         ✓ implemented
│   └── qmldir
├── module-reusable-elements/
│   ├── HoverZone.qml             ✓ implemented
│   ├── PanelButton.qml           ✓ implemented
│   ├── PanelCard.qml             ✓ implemented
│   ├── PanelController.qml       ✓ implemented
│   ├── PanelDivider.qml          ✓ implemented
│   ├── PanelSurface.qml          ✓ implemented
│   ├── PillController.qml        ✓ implemented
│   ├── PillWindow.qml            ✓ implemented
│   ├── SectionLabel.qml          ✓ implemented
│   ├── StatusDot.qml             ✓ implemented
│   ├── TogglePair.qml            ✓ implemented
│   └── qmldir
├── root-processes/
│   ├── CalendarProcess.qml       ✓ implemented
│   ├── ClockProcess.qml          ✓ implemented
│   ├── FifoListener.qml          ✓ implemented
│   ├── MprisProcess.qml          ✓ implemented
│   ├── SettingsProcess.qml       ✓ implemented
│   ├── TasksProcess.qml          ✓ implemented
│   ├── TimerProcess.qml          ✓ implemented
│   ├── ToplevelProcess.qml       ✓ implemented
│   ├── WallpaperProcess.qml      ✓ implemented
│   ├── WeatherProcess.qml        ✓ implemented
│   ├── WorkspaceProcess.qml      ✓ implemented
│   └── qmldir
├── Prefs.qml                     ✓ implemented
├── qmldir
├── shell.qml
└── Style.qml                     ✓ implemented

helper/
├── calendar/
│   └── gcal_fetch.py             ✓ implemented  (symlinked → ~/.local/bin/gcal-fetch)
├── tasks/
│   └── gtask_fetch.py            ✓ implemented  (symlinked → ~/.local/bin/gtask-fetch)
├── google_auth_notify.sh         ✓ implemented  (symlinked → ~/.local/bin/google-auth-notify)
├── wallpaper/
│   └── yin_set.sh                              (symlinked → ~/.local/bin/yin-set)  TBD
└── weather/
    └── weather_fetch.py          ✓ implemented  (symlinked → ~/.local/bin/weather-fetch)
```

See [`done.md`](done.md) for the full breakdown of completed work.
