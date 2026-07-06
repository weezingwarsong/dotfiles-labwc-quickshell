# Pillbox

Pillbox is a Quickshell-based desktop shell — a bar/overlay system in the spirit of Waybar or Noctalia, but built around two distinct visual primitives: Pills and Panels.

### Pill
A small rounded rectangle anchored at the top-center of the screen. Hidden by default. **Smart and context-aware** — it reveals itself automatically when there is something relevant to show, and retreats back into hiding when there is not. It can also be surfaced explicitly by the user.

**Implementation:**
- A single `PanelWindow` anchored top-center of the primary screen. Width is `screen.width * 0.10`, height is `24px`.
- On multi-screen setups, the pill appears on the primary screen only. Primary is defined as the first entry in `Quickshell.screens`, with a config option to override by index.
- All pills share this one window. **Only one pill is ever active at a time.** The window acts as a dumb container — it renders whatever the currently active pill exposes as `displayText` via a `Loader`.
- A two-stage priority system governs which pill shows and when. **Stage 1 — winner:** determined by each pill's `isActive` (or `shouldShow` for transient pills) property. Priority order (highest → lowest): WindowPill → WorkspacePill → MprisPill → TimePill. **Stage 2 — show/hide:** three independent triggers — hover, explicit peek (W-1), or content-driven reveal. Stage 1 and Stage 2 are independent: the winner is always pre-computed so the display is instant when Stage 2 opens the gate.

### Panel
A larger rounded rectangle that appears below the Pill. **Dumb and passive** — it has no opinion about when to appear. It only opens when the user deliberately calls it, and only closes when the user deliberately dismisses it.

**Only one panel is ever shown at a time.** If a panel is already open and the user summons a different panel, the current panel dismisses immediately and the new one takes its place. Last call wins.

---

## Contents

1. [Pillbox](#pillbox) — what it is; pills and panels defined
2. [Target & Philosophy](#target--philosophy) — labwc-only, data-first, one source of truth
3. [Implementation](#implementation) — built modules: processes, reusable elements, pills, panels
4. [Draft Board](#draft-board) — design specs for all modules (done and planned)
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
| `showTime` | Triggers a 5-second peek of the time pill (W-1 toggle) |
| `refreshCalendar` | Tells CalendarProcess to fetch immediately outside its normal cycle |
| `toggleCalendar` | Opens or dismisses the calendar panel |
| `toggleWindowSwitcher` | Opens or dismisses the window switcher panel (W-Tab) |
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

#### PillController ✓

**File:** `module-reusable-elements/PillController.qml`

The single source of truth for all pill show/hide decisions. A `QtObject` — no visuals, pure logic. Every input that could influence pill visibility flows into `PillController`; nothing else makes show/hide decisions.

*Stage 1 — Winner:* Which pill has the most relevant content right now. Pre-computed so the display is instant on reveal. Priority order (highest → lowest): WindowPill → WorkspacePill → MprisPill → TimePill.

Each pill exposes the relevant eligibility signal used at this stage:
- `WindowPill.shouldShow` — true while window switcher panel is open
- `WorkspacePill.shouldShow` — true for 1.5s after workspace switch
- `MprisPill.isActive` — true while a player has an active track (persists; does not auto-expire)
- `TimePill` — always the fallback winner

*Stage 2 — Show/hide:* Three independent triggers:
1. **Hover** — cursor in `HoverZone`. Always works, never suppressible.
2. **Peek** — W-1 keybind via FIFO. Toggles: first press shows for 5 seconds, second press dismisses immediately.
3. **Content-driven** — `winner.shouldShow` is true. Blocked by `_userDismissed` so the user can silence an active condition. `_userDismissed` auto-clears when the condition ends naturally.

Note: `MprisPill.shouldShow` (the 3-second peek on state change) drives Stage 2's content-driven trigger independently of `isActive`. While music plays with no state changes, `shouldShow` is false — the pill won't auto-reveal — but MPRIS still holds the winner slot, so hover and peek surface it.

**Inputs:** `hovered: bool` (from HoverZone), each pill object (reads their `shouldShow` / `isActive`)<br>
**Outputs:** `winner`, `shouldShow: bool`, `activePill` (`winner` if `shouldShow`, else `null`)

---

#### PillWindow ✓

**File:** `module-reusable-elements/PillWindow.qml`

A `PanelWindow` anchored top-center on `Quickshell.screens[0]`. `exclusiveZone: 0` — overlays windows, reserves no screen space. `mask: Region {}` — fully pointer-transparent so `HoverZone` always receives the cursor beneath it.

- `implicitWidth: Screen.width * 0.10`, `implicitHeight: 24`
- `margins.top: Screen.height * 0.01` gap from screen edge
- `Loader { sourceComponent: activePill.visualComponent }` — each pill owns its own visual; `PillWindow` just mounts it. 20px horizontal margins.
- Completely dumb — no logic, no opinions.

---

#### HoverZone ✓

**File:** `module-reusable-elements/HoverZone.qml`

An always-present transparent `PanelWindow`, 8px tall, anchored top-center. Never hides — must always be present to detect cursor entry even when the pill is hidden. Exposes `hovered: bool` with a 120ms leave debounce to prevent edge jitter. Feeds into `PillController.hovered` only.

---

#### PanelController ✓

**File:** `module-reusable-elements/PanelController.qml`

Manages which panel is currently shown. Enforces one-at-a-time: `toggle(panelId)` opens a panel or dismisses it; summoning a different panel replaces the current one immediately.

---

#### PanelSurface ✓

**File:** `module-reusable-elements/PanelSurface.qml`

A separate `PanelWindow` surface centered horizontally, top edge at `Screen.width * 0.10` from screen top. Fixed size: `Screen.width * 0.15` × `Screen.width * 0.15`. Receives `activePanel` and `shouldShow` from `PanelController`, loads the correct panel via `Loader`. Geometry authority — individual panels are content only.

Requests `WlrKeyboardFocus.Exclusive` when the window switcher is active so the filter `TextInput` receives key events directly. Reverts to `WlrKeyboardFocus.None` for all other panels. Forwards a `dismissRequested()` signal from the loaded panel back to `shell.qml`.

---

#### Style.qml ✓

**File:** `Style.qml` (root, `pragma Singleton`)

All visual values (color, font, radius, spacing) go through `Style.qml`. Registered in the root `qmldir` and re-exported via each subdirectory's `qmldir` so all modules can access it without a module import path.

Two sections:
- **Variable Preference** — raw palette tokens: 16-color terminal palette (`color0`–`color15`) seeded with Nord, 2 font families, 7 size steps, 3 border widths, 4 radius steps (`radNone/Light/Med/High`). Intended to be swapped out from wallpaper extraction (pywal/matugen format) in a future phase.
- **Fixed** — semantic mappings: `pillBgColor`, `panelBorderRadius`, `textPrimary`, `fontContentSize`, etc. All components read only from Fixed — never from Variable directly.

Fonts: **JetBrains Mono Nerd Font** (`ttf-jetbrains-mono-nerd`) — monospace text and Nerd Font glyphs. **Sarasa Mono SC** (`ttf-sarasa-gothic`) — CJK fallback, handled transparently by Qt via fontconfig (no explicit `font.families` list needed). `Style.fontCJK` documents the intent. All text items use `font.family: Style.fontMono`; Qt falls back through the system font stack for any glyph JetBrainsMono doesn't cover.

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

Reads from `MprisProcess` (injected). Two separate signals control its behaviour:
- `isActive` — true while `activePlayer` has a non-empty `trackTitle`. This is the Stage 1 winner signal — MPRIS holds the winner slot for the duration of playback.
- `shouldShow` — true for 3 seconds after any `playerUpdated` event (track change or playback state change). This is the Stage 2 content-driven peek signal.

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

## Draft Board

Design specs for all modules — both implemented and planned. Covers intended behavior, data dependencies, reveal conditions, and display logic.

---

### Pills

#### Time

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
| Manual peek | `showTime` via FIFO or hover zone | 5 seconds (PillController) |
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

#### Workspace

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

#### Window

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

#### MPRIS ✓

**File:** `module-pills/MprisPill.qml`

**What we expect from the MPRIS pill:**

Any time the state of a song changes — play, pause, or new track — the pill peeks briefly to confirm the event. While a track is active the MPRIS pill holds the winner slot over TimePill, so hover and explicit peek always surface MPRIS content.

**What we need to make it happen:**

- `MprisProcess` ✓ — binds to `Mpris.players`. Selects the most relevant player (Playing > Paused > first available). Emits `playerUpdated` on any track or playback state change.

**Eligibility (`isActive: bool`):**
- True while `activePlayer` is non-null and `trackTitle` is non-empty. Does not auto-expire. Keeps MPRIS as Stage 1 winner for the duration of playback.

**Reveal conditions (`shouldShow: bool` — Stage 2 content-driven peek):**

| Condition | Trigger | Auto-hide |
|---|---|---|
| Track changed | `MprisProcess.playerUpdated` (new track) | 3 seconds after last event |
| Playback state changed | `MprisProcess.playerUpdated` (play/pause/stop) | 3 seconds after last event |

`shouldShow` is driven by a local `Timer` — each `playerUpdated` signal restarts it; when it fires, `shouldShow` goes false. Rapid events extend the peek window rather than stacking.

**Display (`visualComponent`):**
- Playback state glyph (Nerd Font): `String.fromCodePoint(0xf04b/0xf04c/0xf04d)` — play · pause · stop
- Track title from `activePlayer.trackTitle`

Layout: `[state glyph]  [trackTitle]` — glyph uses `fontNerd`, title uses `fontMono` (Qt falls back through fontconfig to Sarasa for CJK). Title elided right.

---

### Panels

#### Calendar

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

#### Window Switcher

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

## To-Do

### PillController — Priority-based winner selection

**Problem:** Stage 1 winner is a hardcoded `if`-chain in `PillController.qml` that requires bespoke knowledge of each pill's API (`shouldShow` for most, `isActive` for MPRIS). Adding a new pill means editing `PillController`. The inconsistent interface also caused bugs where TimePill shows on hover while music is playing instead of MprisPill.

**Design:** Each pill exposes two reactive bindings. `PillController` only reads these — never pill-specific properties.

- `priority: int` — who wins Stage 1. Higher number wins. Computed binding (never mutated externally). TimePill holds `1` at idle (permanent fallback); other pills return `0` when inactive and rise above `1` when active.
- `shouldReveal: bool` — drives Stage 2 content-driven trigger. Decoupled from `priority` so a pill can be the silent winner (high priority, `shouldReveal: false`) before a second threshold triggers auto-reveal.

**Stage 1** becomes a max-picker with no pill-specific logic:
```qml
readonly property var winner: {
    var pills = [windowPill, workspacePill, mprisPill, timePill].filter(p => p)
    return pills.reduce(function(best, p) {
        return p.priority > (best ? best.priority : -1) ? p : best
    }, null)
}
```

**Stage 2** content-driven trigger replaces `winner.shouldShow` / `winner.isActive` inconsistency:
```qml
property bool contentActive: winner ? winner.shouldReveal : false
```

**Per-pill mappings:**

| Pill | `priority` | `shouldReveal` |
|---|---|---|
| `TimePill` | `10` when calendar ≤10min or timer active; `1` idle | `true` when calendar ≤10min or timer active |
| `MprisPill` | `5` while playing; `0` idle | `true` for 3s after track/state change |
| `WorkspacePill` | `100` during switch; `0` idle | same as priority > 0 |
| `WindowPill` | `200` while switcher open; `0` idle | same as priority > 0 |

**Files to change:** `PillController.qml`, `TimePill.qml`, `MprisPill.qml`, `WorkspacePill.qml`, `WindowPill.qml`. Remove `isActive` from `MprisPill` (replaced by `priority`). No changes to `shell.qml` or any process file.

---

### Media Player Panel

A panel dedicated to media playback control. Summoned deliberately by the user (keybind TBD), distinct from the MPRIS pill which is passive and auto-reveals.

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
- labwc keybind (TBD)

---

### Theme Polish

- [ ] Replace Nord placeholder palette with wallpaper-extracted colors. Logic TBD — likely a helper script that reads dominant colors from the current wallpaper and writes them into the Variable section at startup.

---

## Directory Tree

```
quickshell/
├── module-panels/
│   ├── CalendarPanel.qml         ✓ implemented
│   ├── MediaPlayerPanel.qml
│   ├── TimerWidget.qml           ✓ implemented
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
│   ├── PanelController.qml       ✓ implemented
│   ├── PanelSurface.qml          ✓ implemented
│   ├── PillController.qml        ✓ implemented
│   ├── PillWindow.qml            ✓ implemented
│   └── qmldir
├── root-processes/
│   ├── CalendarProcess.qml       ✓ implemented
│   ├── ClockProcess.qml          ✓ implemented
│   ├── FifoListener.qml          ✓ implemented
│   ├── MprisProcess.qml          ✓ implemented
│   ├── TasksProcess.qml          ✓ implemented
│   ├── TimerProcess.qml          ✓ implemented
│   ├── ToplevelProcess.qml       ✓ implemented
│   ├── WeatherProcess.qml        ✓ implemented
│   ├── WorkspaceProcess.qml      ✓ implemented
│   └── qmldir
├── qmldir
├── shell.qml
└── Style.qml                     ✓ implemented

helper/
├── calendar/
│   └── gcal_fetch.py             ✓ implemented  (symlinked → ~/.local/bin/gcal-fetch)
├── tasks/
│   └── gtask_fetch.py            ✓ implemented  (symlinked → ~/.local/bin/gtask-fetch)
├── google_auth_notify.sh         ✓ implemented  (symlinked → ~/.local/bin/google-auth-notify)
└── weather/
    └── weather_fetch.py          ✓ implemented  (symlinked → ~/.local/bin/weather-fetch)
```

See [`done.md`](done.md) for the full breakdown of completed work.
