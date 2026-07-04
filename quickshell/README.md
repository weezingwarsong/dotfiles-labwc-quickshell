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
| `CalendarProcess` | upcoming events, next event start time | See [Processes → CalendarProcess](#calendarprocess) |
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
| `CalendarPanel` | `CalendarProcess` | — |
| `WindowSwitcherPanel` | `ToplevelProcess` | `switchToWindow(toplevel)` |
| `MediaPlayerPanel` | `MprisProcess` | `playPause()`, `next()`, `previous()` |

### Phase 4 — Visuals *(in progress)*
- Wrap pills in `PillWindow` — the shared visual container in `module-reusable-elements/` ✓
- Wrap panels in a shared panel visual shell (larger rect, positioned below pill, shown/hidden by explicit user calls)
- Reusable visual primitives live in `module-reusable-elements/`

**Wiring (in `shell.qml`):**
```
HoverZone ──► PillController ──► PillWindow
TimePill  ──►      (judge)   ──► (renderer)
```
`HoverZone` and each pill feed into `PillController`. `PillController` outputs `activePill` and `shouldShow`. `PillWindow` renders `activePill.displayText` and sets `visible: shouldShow`. No other component makes show/hide decisions.

**`PillController.qml`** (`module-reusable-elements/PillController.qml`):
The single source of truth for all show/hide decisions. A `QtObject` — no visuals, pure logic. Every input that could influence pill visibility flows into `PillController`; nothing else makes show/hide decisions.

Two explicit stages:

*Stage 1 — Winner:* Which pill has the most relevant content right now, computed independently of whether anything is showing. Pre-computed so the display is instant on reveal. Priority order is TBD and will be defined as pills are completed. Currently `TimePill` is always the winner — it is the only pill.

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
- Renders `activePill.displayText` inside a rounded `Rectangle`
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
| `showTime` | Tells TimePill to reveal and start its auto-hide timer |
| `refreshCalendar` | Tells CalendarProcess to fetch immediately outside its 5-minute cycle |
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

Starts with Pillbox, dies with Pillbox. Fetches upcoming calendar events from Google Calendar via gcalcli and exposes them to the rest of Pillbox.

**Fetch behaviour:**
- Fetches automatically every 5 minutes via `QtQuick.Timer`
- Fetches immediately on receiving the `refreshCalendar` command from `FifoListener`
- On fetch failure (no network, expired token), retains the last known events list silently — no crash, no clear

**Exposes:**
- `events` — list of upcoming events, each with title and start time
- `nextEvent` — convenience property pointing to the soonest upcoming event
- `lastUpdated` — timestamp of the last successful fetch

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

- `ClockProcess` — ticks every second, exposes current time as a formatted string and raw datetime. Required for all three conditions.
- **User-initiated peek (condition 1)** — two complementary triggers, both set the same `showTime` flag and start the same auto-hide timer:
  - *Global keybind*: handled by labwc via `rc.xml`. The keybind runs `echo "showTime" > ~/.local/share/pillbox/pillbox.fifo`. The `rc.xml` entry is outside this repo but must be documented so the setup is reproducible.
  - *Mouse hover zone*: Quickshell renders a thin invisible `MouseArea` strip anchored at the top-center of the screen. When the cursor enters it, `showTime` triggers. Self-contained in Quickshell, no labwc config needed.
- `CalendarProcess` — fetches upcoming events and exposes the next event's start time. TimePill watches the gap between now and next event; when it drops to 10 minutes, `shouldShow` becomes true. Hides after the event start time passes.
- `TimerProcess` — tracks user-set countdown state (duration, time started, running/stopped). TimePill watches `active`; when true, `shouldShow` becomes true. Hides when countdown reaches zero or stopwatch is stopped.

**Reveal conditions (`shouldShow: bool`):**

| Condition | Trigger | Auto-hide |
|---|---|---|
| Manual peek | `showTime` via FIFO or hover zone | 5 seconds |
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

## Directory Structure

```
quickshell-rewrite/
├── module-panels/
│   ├── CalendarPanel.qml
│   ├── MediaPlayerPanel.qml
│   ├── WindowSwitcherPanel.qml
│   └── qmldir
├── module-pills/
│   ├── MprisPill.qml
│   ├── ScreenrecPill.qml
│   ├── TimePill.qml          ✓ implemented
│   ├── WindowPill.qml
│   ├── WorkspacePill.qml
│   └── qmldir
├── module-reusable-elements/
│   ├── HoverZone.qml         ✓ implemented
│   ├── PillController.qml    ✓ implemented
│   ├── PillWindow.qml        ✓ implemented
│   └── qmldir
├── root-processes/
│   ├── CalendarProcess.qml   ✓ implemented
│   ├── ClockProcess.qml      ✓ implemented
│   ├── FifoListener.qml      ✓ implemented
│   ├── TimerProcess.qml      ✓ implemented
│   └── qmldir
├── qmldir
└── shell.qml
```
