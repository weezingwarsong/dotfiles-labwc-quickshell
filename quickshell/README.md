# Pillbox

Pillbox is a Quickshell-based desktop shell — a bar/overlay system in the spirit of Waybar or Noctalia, but built around two distinct visual primitives: Pills and Panels.

## Visual Elements

### Pill
A small rounded rectangle anchored at the top-center of the screen. Hidden by default. **Smart and context-aware** — it reveals itself automatically when there is something relevant to show, and retreats back into hiding when there is not. It can also be surfaced explicitly by the user.

**Implementation:**
- A single `PanelWindow` anchored top-center of the primary screen. Width is `screen.width * 0.10`, height is `24px`.
- On multi-screen setups, the pill appears on the primary screen only. Primary is defined as the first entry in `Quickshell.screens`, with a config option to override by index.
- All pills share this one window. **Only one pill is ever active at a time.** The window acts as a dumb container — it renders whatever the currently active pill exposes as `displayText` via a `Loader`.
- A priority system determines which pill wins when multiple pills have `shouldShow: true` simultaneously. **Designing this priority system is the single greatest challenge of the project.** It is deferred — we will cross that bridge when all pills are functionally complete.

### Panel
A larger rounded rectangle that appears below the Pill. **Dumb and passive** — it has no opinion about when to appear. It only opens when the user deliberately calls it, and only closes when the user deliberately dismisses it.

**Only one panel is ever shown at a time.** If a panel is already open and the user summons a different panel, the current panel dismisses immediately and the new one takes its place. Last call wins.

---

## Build Plan

### Target
**labwc only.** No Hyprland, Niri, or other compositor support. Data comes from standard Wayland protocols and Quickshell's built-in backends — no compositor-proprietary IPC.

### Philosophy
Functionality before visuals. Every pill and panel must have its data plumbing and logic fully working — verified via `console.log` in the quickshell process terminal — before any visual layer is added. If visuals break, they can be purged and rewritten without touching the data layer.

### Phase 1 — Root Processes (`root-processes/`)
Write always-running singleton processes that fetch and expose live data. All pills and panels read from these; nothing fetches its own data directly. Sources:

| Process | Data | Backend |
|---|---|---|
| `FifoListener` | incoming commands from external sources (keybinds, scripts) | See [Processes → FifoListener](#fifolistener) |
| `ClockProcess` | current time (formatted string + raw datetime) | See [Processes → ClockProcess](#clockprocess) |
| `CalendarProcess` | upcoming events, today/week views, month dot map | See [Processes → CalendarProcess](#calendarprocess) |
| `TasksProcess` | tasks by due date, overdue, today/week views | See [Processes → TasksProcess](#tasksprocess) |
| `TimerProcess` | countdown/stopwatch state, display text | See [Processes → TimerProcess](#timerprocess) |

Validate each by printing properties to console on change. No visuals yet.

### Phase 2 — Pills (`module-pills/`)
Each pill is a pure data component: it binds to one or more root processes and exposes clean properties. No rectangles, no colors, no animations yet. Validate by console-logging the exposed properties.

| Pill | Data source |
|---|---|
| `TimePill` | `ClockProcess`, `CalendarProcess`, `TimerProcess` — See [Pills → Time](#time) |
| `WorkspacePill` | `WorkspaceProcess` |
| `WindowPill` | `ToplevelProcess` |
| `MprisPill` | `MprisProcess` |
| `ScreenrecPill` | `ScreenrecProcess` |

Each pill also defines its **reveal condition** — the boolean logic that determines when it should be visible — as a plain property (`shouldShow: bool`).

### Phase 3 — Panels (`module-panels/`)
Each panel is a data + actions component: it binds to root processes and exposes both properties and callable actions (e.g. `switchToWindow()`, `playPause()`). No visuals yet. Validate via console.

| Panel | Data source | Actions |
|---|---|---|
| `CalendarPanel` | `CalendarProcess`, `TasksProcess`, `WeatherProcess` | — |
| `WindowSwitcherPanel` | `ToplevelProcess` | `switchToWindow(toplevel)` |
| `MediaPlayerPanel` | `MprisProcess` | `playPause()`, `next()`, `previous()` |

### Phase 4 — Visuals *(in progress)*
- Wrap pills in `PillWindow` — the shared visual container in `module-reusable-elements/` ✓
- Wrap panels in a shared panel visual shell (larger rect, positioned below pill, shown/hidden by explicit user calls) ✓
- Reusable visual primitives live in `module-reusable-elements/`

**Every visual value (color, font, radius, spacing) goes through `Style.qml`** — a singleton in the root `quickshell/` directory. No component hardcodes a color or font size directly. Components read from `Style` instead: `color: Style.pillBg`, `font.pixelSize: Style.textSm`, etc.

`Style.qml` is a stub — the properties need to be extracted from the components that currently hardcode them. The components that carry visual values and need to be migrated are:

| Component | Location | Renders |
|---|---|---|
| `PillWindow.qml` | `module-reusable-elements/` | Pill shell — rounded rect, background, border, text color and font for all pills |
| `TimePill.qml` | `module-pills/` | Time string or timer countdown |
| `WorkspacePill.qml` | `module-pills/` | Current workspace name/number |
| `MprisPill.qml` | `module-pills/` | Track title and artist |
| `ScreenrecPill.qml` | `module-pills/` | Recording indicator |
| `WindowPill.qml` | `module-pills/` | Active window title |
| `CalendarPanel.qml` | `module-panels/` | Calendar glance + expanded — date, weather, month grid, events, tasks, timer |
| `MediaPlayerPanel.qml` | `module-panels/` | MPRIS player controls |
| `WindowSwitcherPanel.qml` | `module-panels/` | Switchable window list |

**Wiring (in `shell.qml`):**
```
HoverZone ──► PillController ──► PillWindow
TimePill  ──►      (judge)   ──► (renderer)
```
`HoverZone` and each pill feed into `PillController`. `PillController` outputs `activePill` and `shouldShow`. `PillWindow` renders `activePill.displayText` and sets `visible: shouldShow`. No other component makes show/hide decisions.

**`PillController.qml`** (`module-reusable-elements/PillController.qml`):
The single source of truth for all show/hide decisions. A `QtObject` — no visuals, pure logic. Every input that could influence pill visibility flows into `PillController`; nothing else makes show/hide decisions.

Two explicit stages:

*Stage 1 — Winner:* Which pill has the most relevant content right now, computed independently of whether anything is showing. Pre-computed so the display is instant on reveal. Priority order (highest → lowest): WorkspacePill (workspace flash, time-critical) → TimePill (calendar imminent, timer active, or default time display).

*Stage 2 — Show/hide:* Whether to show the pill at all. Three independent triggers evaluated in order:
1. **Hover** — cursor in `HoverZone`. Always works, never suppressible.
2. **Peek** — W-1 keybind via FIFO. Toggles: first press shows for 5 seconds, second press dismisses immediately. Sets `_userDismissed` on dismiss.
3. **Content-driven** — `winner.shouldShow` is true (calendar imminent, timer active, etc.). Blocked by `_userDismissed` so the user can silence an active condition. `_userDismissed` auto-clears when the content condition ends naturally, so future conditions are not silenced.

Inputs:
- `hovered: bool` — from `HoverZone`
- `timePill` (and future pills) — `PillController` reads their `shouldShow`

Outputs:
- `winner` — the pill with highest-priority content (pre-computed, always ready)
- `shouldShow: bool` — the final gate
- `activePill` — `winner` if `shouldShow`, else `null`; passed to `PillWindow`

**`PillWindow.qml`** (`module-reusable-elements/PillWindow.qml`):
- A `PanelWindow` anchored top-center on `Quickshell.screens[0]` (primary screen)
- `exclusiveZone: 0` — overlays windows, reserves no screen space
- `implicitWidth: Screen.width * 0.10`, `implicitHeight: 24`
- `mask: Region {}` — fully pointer-transparent so `HoverZone` below it always receives the cursor
- Receives `activePill` and `shouldShow` as injected properties from `shell.qml`
- `Loader { sourceComponent: activePill.visualComponent }` — each pill owns its own visual component; `PillWindow` just mounts it. 20px horizontal margins. `margins.top: Screen.height * 0.01` gap from screen edge.
- Completely dumb — no logic, no opinions. All decisions are made upstream in `PillController`.

**`HoverZone.qml`** (`module-reusable-elements/HoverZone.qml`):
- An always-present transparent `PanelWindow`, 8px tall, anchored top-center
- Never hides — must always be present to detect cursor entry even when pill is hidden
- Exposes `hovered: bool` with a 120ms leave debounce to prevent edge jitter
- Feeds into `PillController.hovered` only — does not talk to `PillWindow` directly

**`TimePill.shouldShow`** is content-driven only — calendar imminent or timer active. User-initiated triggers (hover, W-1 peek) live in `PillController`, not in the pill. Pills declare what content they have; `PillController` decides when to show it.

### Rule: One Source of Truth
No pill or panel may fetch its own data. All data flows from `root-processes/` down. This makes the data layer independently testable and prevents duplicated IPC connections.

---

## Processes

### FifoListener

**File:** `root-processes/FifoListener.qml`

Starts with Pillbox, dies with Pillbox. Tails a named pipe at `~/.local/share/pillbox/pillbox.fifo` using a `Process`. Any external tool — labwc keybinds, shell scripts, other processes — can send commands to Pillbox by writing a string to that pipe. `FifoListener` reads each line, pattern-matches the command, and emits the appropriate signal for the rest of Pillbox to react to.

This is the general command bus for all external input into Pillbox.

**Known commands:**

| Command | Effect |
|---|---|
| `showTime` | Triggers a 5-second peek of the time pill (W-1 toggle) |
| `refreshCalendar` | Tells CalendarProcess to fetch immediately outside its normal cycle |
| `setTimer:N` | Tells TimerProcess to set a countdown for N seconds |
| `startTimer` | Tells TimerProcess to start or resume the countdown |
| `pauseTimer` | Tells TimerProcess to pause the countdown |
| `resetTimer` | Tells TimerProcess to reset the countdown |
| `startStopwatch` | Tells TimerProcess to start stopwatch mode |
| `stopStopwatch` | Tells TimerProcess to stop the stopwatch |
| `resetStopwatch` | Tells TimerProcess to reset the stopwatch |

---

### ClockProcess

**File:** `root-processes/ClockProcess.qml`

Starts with Pillbox, dies with Pillbox. A `QtQuick.Timer` fires every second and updates the exposed time properties. All time-aware pills bind to this single source — nothing reads `new Date()` on its own.

**Exposes:**
- `displayTime` — formatted string `"HH:mm"` for display in the pill
- `displayTimeFull` — formatted string `"HH:mm:ss"` for debug/logging
- `now` — raw JavaScript `Date` object, used by TimePill to compute time-to-next-event

---

### CalendarProcess

**File:** `root-processes/CalendarProcess.qml`

Starts with Pillbox, dies with Pillbox. Fetches upcoming calendar events from Google Calendar via `gcal-fetch` (a Python script at `helper/calendar/gcal_fetch.py`, symlinked to `~/.local/bin/gcal-fetch`). Exposes pre-computed views so panels never re-filter the raw list.

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

**All-day events:** `start` and `end` are date-only strings (`"2026-07-04"`). Timed events use ISO 8601 with timezone (`"2026-07-04T14:00:00+08:00"`). `allDay: bool` distinguishes them. `nextEvent` and date filtering handle both correctly.

---

### TasksProcess

**File:** `root-processes/TasksProcess.qml`

Starts with Pillbox, dies with Pillbox. Fetches tasks from Google Tasks via `gtask-fetch` (a Python script at `helper/tasks/gtask_fetch.py`, symlinked to `~/.local/bin/gtask-fetch`). Follows the same shape as `CalendarProcess`.

**Fetch behaviour:**
- Same 10-second startup delay and 5-minute repeat as `CalendarProcess`
- Fetches all incomplete tasks and completed tasks from the last 30 days
- Network and auth errors handled identically to `CalendarProcess` — logged, notified, last known data retained

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

### TimerProcess

**File:** `root-processes/TimerProcess.qml`

Starts with Pillbox, dies with Pillbox. Owns all timer and stopwatch state. No pill or panel holds timer state directly — they all read from here.

**Modes:**
- *Countdown* — counts down from a user-set duration to zero
- *Stopwatch* — counts up from zero indefinitely

**State:**
- `mode` — `"timer"` or `"stopwatch"`
- `running` — bool
- `duration` — total seconds set (countdown only)
- `remaining` — seconds left (countdown only)
- `elapsed` — seconds passed (stopwatch)
- `displayText` — computed human-readable string (e.g. `"4:32"`) ready to print directly into any pill or panel

**Controlled entirely via FIFO commands** — no component talks to TimerProcess directly to mutate state. A future timer UI panel sends commands through `FifoListener` the same as any external tool.

| FIFO Command | Effect |
|---|---|
| `setTimer:300` | Set a countdown for N seconds |
| `startTimer` | Start or resume the countdown |
| `pauseTimer` | Pause the countdown |
| `resetTimer` | Reset countdown to original duration |
| `startStopwatch` | Start stopwatch mode |
| `stopStopwatch` | Stop the stopwatch |
| `resetStopwatch` | Reset stopwatch to zero |

**TimePill reveal condition (TBD):** whether the pill shows for the entire duration of a running timer, or only when time is nearly up, is yet to be decided. Currently implemented as: show whenever a timer or stopwatch is active.

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
| Manual peek | `showTime` via FIFO or hover zone | 5 seconds (PillController) |
| Calendar imminent | next event ≤ 10 minutes away | when event start time passes |
| Timer/stopwatch active | `TimerProcess.active === true` | when timer finishes or stopwatch stops |

**Display text (`displayText: string`):**
- Timer or stopwatch active → `TimerProcess.displayText` (e.g. `"04:32"`)
- Otherwise → `ClockProcess.displayTime` (e.g. `"14:07"`)

**Process references** are injected by `shell.qml` as properties (`clockProcess`, `calendarProcess`, `timerProcess`). The pill does not reach for globals.

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

A workspace OSD — the same role labwc's built-in workspace indicator fills, but routed through the pill. Any time the active workspace changes, regardless of what caused it (keybind, `rofi -show window` jumping to a window on another workspace, a script, anything), the pill surfaces briefly to confirm the switch, then retreats.

**What we need to make it happen:**

- `WorkspaceProcess` — a thin QML `QtObject` that binds to `WindowManager.windowsets` from `import Quickshell.WindowManager`. No subprocess. Derives `current` (the `Windowset` where `active === true`) and `list` (all workspace names). Emits `workspaceChanged` whenever `current` changes.

**Reveal conditions (`shouldShow: bool`):**

| Condition | Trigger | Auto-hide |
|---|---|---|
| Workspace switched | `WorkspaceProcess.workspaceChanged` | 1.5 seconds after the last change |

`shouldShow` is driven entirely by a local `Timer` inside `WorkspacePill` — on `workspaceChanged`, the timer (re)starts; when it fires, `shouldShow` goes false. No persistent show. Re-triggering before the timer expires resets the countdown, so rapid switches don't stack.

**Display text (`displayText: string`):**
- Current workspace name — e.g. `"1"`, `"2"`, or a named workspace like `"web"`

**Process reference** (`workspaceProcess`) injected by `shell.qml` as a property, same pattern as other pills.

---

## Panels

### Calendar

**What we expect from the Calendar panel:**

The panel has two states: **glance** (default, compact) and **expanded** (user-triggered, shows more detail). Both states are within the same panel — not separate panels.

**Glance view** — visible immediately when the panel opens:
1. Today's date — day of week, day, month, year.
2. Today's events — list of events for the current day with their times.
3. Month view — mini calendar grid showing the current month. Days with events are visually marked. Hovering a day shows a tooltip with that day's events. User can navigate forward/backward by month.
4. Today's weather — current conditions and temperature.
5. Today's tasks — task list for the current day (from Google Tasks).
6. Edit button — opens the browser to Google Calendar so the user can edit events there. No in-panel editing.

**Expanded view** — user scrolls or taps to reveal:
1. 7-day full schedule — all events across the next 7 days.
2. 7-day tasks — task list across the next 7 days.
3. 7-day weather forecast — daily conditions and temperature for the week ahead.
4. Timer/stopwatch — set and control a countdown or stopwatch directly from the panel (sends commands through `TimerProcess` via FIFO, same as keybinds).

**Not in scope (by design):**
- In-panel event creation or editing — browser handles this. The panel is read-only except for the timer.
- Multiple calendar account switching — single Google account only.

---

## ✓ Calendar Panel — complete
## ✓ Workspace Pill — complete

See [`done.md`](done.md) for the full breakdown of everything built.

---

## File Tree

```
quickshell/
├── module-panels/
│   ├── CalendarPanel.qml         ✓ implemented
│   ├── MediaPlayerPanel.qml
│   ├── WindowSwitcherPanel.qml
│   └── qmldir
├── module-pills/
│   ├── MprisPill.qml
│   ├── ScreenrecPill.qml
│   ├── TimePill.qml          ✓ implemented
│   ├── WindowPill.qml
│   ├── WorkspacePill.qml     ✓ implemented
│   └── qmldir
├── module-reusable-elements/
│   ├── HoverZone.qml         ✓ implemented
│   ├── PanelController.qml   ✓ implemented
│   ├── PanelSurface.qml      ✓ implemented
│   ├── PillController.qml    ✓ implemented
│   ├── PillWindow.qml        ✓ implemented
│   └── qmldir
├── root-processes/
│   ├── CalendarProcess.qml   ✓ implemented
│   ├── ClockProcess.qml      ✓ implemented
│   ├── FifoListener.qml      ✓ implemented
│   ├── TasksProcess.qml      ✓ implemented
│   ├── TimerProcess.qml      ✓ implemented
│   ├── WeatherProcess.qml    ✓ implemented
│   ├── WorkspaceProcess.qml  ✓ implemented
│   └── qmldir
├── qmldir
├── shell.qml
└── Style.qml                     ✗ stub — visual constants not yet extracted

helper/
├── calendar/
│   └── gcal_fetch.py         ✓ implemented  (symlinked → ~/.local/bin/gcal-fetch)
├── tasks/
│   └── gtask_fetch.py        ✓ implemented  (symlinked → ~/.local/bin/gtask-fetch)
├── google_auth_notify.sh     ✓ implemented  (symlinked → ~/.local/bin/google-auth-notify)
└── weather/
    └── weather_fetch.py      ✓ implemented  (symlinked → ~/.local/bin/weather-fetch)
```
