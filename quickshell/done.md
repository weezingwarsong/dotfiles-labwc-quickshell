# Completed Work

---

## Calendar Panel

Everything that was required before the Calendar panel was functional.

### Data layer

- [x] `CalendarProcess` — fetches events, exposes `nextEvent`, `todayEvents`, `weekEvents`, `eventsByDate`
- [x] `TasksProcess` — fetches tasks, exposes `todayTasks`, `weekTasks`, `overdueTasks`, `tasksByDate`
- [x] `gcal-fetch` — Python script, Google Calendar API, auth shared with `gtask-fetch`
- [x] `gtask-fetch` — Python script, Google Tasks API, shared token
- [x] `google-auth-notify` — re-auth notification with action button, shared by both scripts
- [x] `WeatherProcess` — fetches weather, exposes `current` and `forecast` (7-day array)
- [x] `weather-fetch` — Python script, Open-Meteo API (keyless), IP geolocation via ipapi.co (24h cached). Exposes current conditions + 7-day forecast with Nerd Font icons.

### Infrastructure

- [x] `PanelController.qml` — `QtObject` in `module-reusable-elements/`. Manages which panel is currently shown. Enforces one-at-a-time: `toggle(panelId)` opens a panel or dismisses it; summoning a different panel replaces the current one immediately.
- [x] `PanelSurface.qml` — separate `PanelWindow` surface in `module-reusable-elements/`, centered horizontally, top of panel at `Screen.width * 0.10` from screen top. Fixed size: `Screen.width * 0.15` × `Screen.width * 0.15` (square on any 16:9 screen). Dumb renderer — receives `activePanel` and `shouldShow` from `PanelController`, loads the correct panel via `Loader` which fills the surface. Named `PanelSurface` to avoid shadowing Quickshell's own `PanelWindow` type.

  **Geometry lives here, not in individual panels** — same reason `PillWindow` owns its own size rather than asking each pill. The surface is the geometry authority; panels are content. All panels share the same size and position for now. When a future panel genuinely needs a different size, `PanelSurface` handles it with a lookup by `activePanel` (same pattern as the old `_panelWidthFrac`), not by deferring to the panel itself.
- [x] **FIFO command** — `toggleCalendar` added to `FifoListener`, wired to `panelController.toggle("calendar")` in `shell.qml`.
- [x] **labwc keybind** — W-2 writes `toggleCalendar` to the FIFO.

### Panel UI

- [x] `CalendarPanel.qml` — in `module-panels/`. Reads from `CalendarProcess`, `TasksProcess`, `ClockProcess`, `WeatherProcess`, and `TimerProcess` (injected via `PanelSurface.qml`'s `onLoaded`). Two states: glance and expanded, both scrollable via `Flickable`.
  - [x] Glance: date header + weather (icon, temp, condition, high/low)
  - [x] Glance: today's events list (up to 3, time + title)
  - [x] Glance: month grid with event/task dot indicators, today highlighted
  - [x] Glance: month navigation (prev/next)
  - [x] Glance: today's tasks list (up to 3)
  - [x] Glance: today's weather
  - [x] Glance: edit button (`Qt.openUrlExternally("https://calendar.google.com")`)
  - [x] Expanded: 7-day schedule grouped by date
  - [x] Expanded: 7-day tasks grouped by due date
  - [x] Expanded: 7-day weather forecast (icon + condition + high/low per day)
  - [x] Expanded: timer/stopwatch controls (preset durations, start/pause/reset, mode switcher — all write to FIFO)
