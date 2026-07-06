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

- [x] `CalendarPanel.qml` — in `module-panels/`. Reads from `CalendarProcess`, `TasksProcess`, `ClockProcess`, `WeatherProcess`, and `TimerProcess` (injected via `PanelSurface.qml`'s `onLoaded`). Three views: glance, expanded, timer — each a separate `Flickable`, navigated by explicit buttons. `Quickshell.Io` import and FIFO writer removed; timer calls `TimerProcess` methods directly.
  - [x] Glance: date header + weather (icon, temp, condition, high/low)
  - [x] Glance: today's events list (up to 3, time + title)
  - [x] Glance: month grid with event/task dot indicators, today highlighted
  - [x] Glance: month navigation (prev/next)
  - [x] Glance: today's tasks list (up to 3)
  - [x] Glance: today's weather
  - [x] Glance: footer row — `More ↓` (→ expanded), `Timer` (→ timer view), `Edit ↗` (Google Calendar in browser)
  - [x] Expanded: `↑ Back` → glance
  - [x] Expanded: 7-day schedule grouped by date
  - [x] Expanded: 7-day tasks grouped by due date
  - [x] Expanded: 7-day weather forecast (icon + condition + high/low per day)
  - [x] Timer view: `↑ Back` + `TimerWidget`

- [x] **Layout refactor** — `CalendarPanel.qml` migrated from `Column`/`Row`/`Grid` with manual `x: 12` / `width: parent.width - 24` arithmetic to `ColumnLayout`/`RowLayout`/`GridLayout` with `anchors.margins: 12`. Forecast row width calculation replaced with `Layout.fillWidth: true`. Tooltip `contentItem` uses `ColumnLayout`.

- [x] `TimerWidget.qml` — new component in `module-panels/`. Injected with `timerProcess: var`. Calls `TimerProcess` methods directly (no FIFO round-trip).
  - [x] Clock face: large `HH:MM:SS` monospace display + `.cs` centiseconds in smaller text (bottom-aligned). Single `Text` binding on `timerProcess.displayText`; centiseconds from `timerProcess.displayCenti`.
  - [x] Mode toggle button — cycles countdown ↔ countup via `timerProcess.setMode(m)`. Resets and stops without starting.
  - [x] Start/Stop button — routes to `startTimer`/`pauseTimer` or `startStopwatch`/`stopStopwatch` per mode.
  - [x] Duration button (countdown mode only) — label shows current duration formatted as `Xh:Xm:Xs` (e.g. `1m:30s`, `25m`). Click expands inline `TextInput`; scroll up/down via `WheelHandler` adjusts by ±5s (min 5s).
  - [x] Expandable duration input — parses `Xh:Xm:Xs` free-form (e.g. `25m`, `1h:30m`, `1h:1m:30s`). Confirms on Enter, cancels on Escape or focus loss. Auto-hides when mode switches to countup.
  - [x] Reset button — `resetTimer()` or `resetStopwatch()` per mode.

- [x] **`TimerProcess` rewrite** — 50ms tick interval (`Date.now()` delta tracking — drift-free vs. tick-counting). `displayText` changed from `"M:SS"` to `"HH:MM:SS"`. Added `displayCenti: string` — `.cs` suffix shown always in countup, and in countdown's last 10 active seconds only. Default `duration: 90` (1m 30s) initialised in `Component.onCompleted`. Added `setMode(m)` for mode switching without starting. All existing FIFO-facing method names preserved (`startTimer`, `pauseTimer`, `resetTimer`, `startStopwatch`, `stopStopwatch`, `resetStopwatch`, `setTimer`).

---

## Theme Polish

- [x] Wire `CalendarPanel.qml` fully to the new Fixed property names.
- [x] Audit all remaining hardcoded values in `CalendarPanel.qml` and map them to `Style` Fixed properties.

---

## Workspace Pill

### Data layer

- [x] `WorkspaceProcess` — pure QML `Item`, no subprocess. Binds to `Quickshell.WindowManager`. `Instantiator` over `WindowManager.windowsets` creates one `Connections` watcher per `Windowset`. When any `Windowset.active` flips true, `current` updates and `workspaceChanged` fires.
  - `current` — the active `Windowset` object (has `.name`, `.active`, `.activate()`)
  - `list` — ordered array of all workspace names, computed binding over `WindowManager.windowsets`
  - `currentIndex` — index of `current` in `WindowManager.windowsets`, compared by object reference
  - `signal workspaceChanged(var workspace)` — emitted on every switch

### Pill

- [x] `WorkspacePill` — binds to `WorkspaceProcess`.
  - `shouldShow: bool` — true for 1.5 seconds after each `workspaceChanged`. Local `Timer` restarts on rapid switches so the pill stays visible until the user settles.
  - `displayText: string` — `workspaceProcess.current.name`
  - `visualComponent: Component` — workspace name on the left + Nerd Font radiobox glyphs (one per workspace, `nf-md-radiobox_marked` U+F0445 for active, `nf-md-radiobox_blank` U+F0444 for inactive). Count is dynamic from `workspaceProcess.list.length` — not hardcoded.

### Visual layer

- [x] `PillWindow` switched from hardcoded `Text` to `Loader { sourceComponent: activePill.visualComponent }` — each pill now owns its own visual component. `TimePill` has a simple `Text` visualComponent; `WorkspacePill` has the name + dots layout. Left/right margins: 20px. Gap from screen top: `Screen.height * 0.01`.

### Wiring

- [x] `WorkspaceProcess { id: workspace }` instantiated in `shell.qml`
- [x] `WorkspacePill { id: workspacePill; workspaceProcess: workspace }` instantiated in `shell.qml`
- [x] `PillController` — `workspacePill` registered as priority 1 (beats `timePill` whenever `workspacePill.shouldShow` is true — workspace flash is time-critical)

---

## Style.qml

### Variable palette redesign

- [x] Replaced the interpolated 16-step grayscale ramp with the standard Nord terminal palette (nord0–nord15 in terminal-color order). Same format that pywal/matugen output — future wallpaper extraction is a drop-in swap of the 16 hex values.
- [x] Removed separate Accent Palette (accent0–accent5) — frost blues folded into color7–color10, aurora accents into color11–color15.
- [x] Simplified border-radius tokens: `radNone(0)` / `radLight(4)` / `radMed(6)` / `radHigh(10)`, replacing five ad-hoc `rad*` names.
- [x] All 16 color tokens annotated with Nord name + semantic usage comment.

### Fixed (semantic mapping) updates

- [x] All Fixed properties updated to reference new color0–color15 and radNone/Light/Med/High tokens.
- [x] `accentBgColor` / `accentBgHover` derived via `Qt.darker(color10, …)` — no orphaned hex literals outside the Variable section.
- [x] Added `textCritical` (color11 — aurora red) and `textSuccess` (color14 — aurora green) — aurora states now exposed as semantic tokens.

### Wiring

- [x] `CalendarPanel.qml` — all Style references updated to current Fixed property names (54 lines). Old short-form names (`textXs`, `surfaceLow`, `radiusBtn`, `accent`, …) replaced with canonical Fixed names (`fontContentSize`, `surfaceLowColor`, `radButton`, `borderAccentColor`, …).
- [x] `PillWindow.qml`, `TimePill.qml`, `WorkspacePill.qml` — already using correct Fixed property names; no changes needed.

---

## Window Switcher

### Data layer

- [x] `ToplevelProcess` — pure QML `Item`, no subprocess. Binds to `Quickshell.Wayland.ToplevelManager` (zwlr-foreign-toplevel-management-v1 protocol).
  - `windows` — `ToplevelManager.toplevels` (`ObjectModel<Toplevel>`). Iterate in JS via `.values`.
  - `focused` — alias for `ToplevelManager.activeToplevel`. Native compositor tracking — no manual `Instantiator` + `Connections` needed for focus. Updates reactively via `onActiveToplevelChanged`.
  - A lightweight `Instantiator` kept only for add/remove logging.
  - Key lesson: `ObjectModel` does not expose `.length` directly in JS — use `.values.length`. `ToplevelManager.activeToplevel` makes manual activated-flag tracking entirely unnecessary.

### Pill

- [x] `WindowPill` — binds to `ToplevelProcess` (injected).
  - `shouldShow` is set externally by `shell.qml` as `panelController.activePanel === "windowSwitcher"`. Visible only during active switching, not as a passive always-on indicator.
  - `visualComponent` — Nerd Font app glyph (resolved by `_glyphFor(appId)`) + `focused.appId` text label.

### Panel

- [x] `WindowSwitcherPanel` — `FocusScope`, reads from `ToplevelProcess.windows` (injected).
  - `filteredWindows` — computed JS array from `toplevelProcess.windows.values`, filtered by case-insensitive `appId + title` match.
  - `selectedFlat: int` — keyboard cursor; resets to 0 on filter text change, clamped on arrow keys, synced from hover.
  - Auto-focus: `Qt.callLater(filterInput.forceActiveFocus)` on `Component.onCompleted`.
  - Enter → `filteredWindows[selectedFlat].activate()` + `dismissed()`. Escape → `dismissed()` only.
  - `_glyphFor(appId)` — Nerd Font lookup for 13 app categories + fallback.

### Infrastructure

- [x] `PanelSurface` — added `toplevelProcess` property, `dismissRequested()` signal, `WlrKeyboardFocus.Exclusive` when `activePanel === "windowSwitcher"`, `"windowSwitcher"` Loader case, `focus: true` on Loader.
- [x] `PillController` — `windowPill` registered at highest priority (WindowPill → WorkspacePill → TimePill).
- [x] `FifoListener` — `toggleWindowSwitcherRequested` signal, `"toggleWindowSwitcher"` command dispatch.
- [x] `shell.qml` — `ToplevelProcess { id: toplevels }`, `WindowPill` wired, `panelController.toggle("windowSwitcher")` on FIFO command, `onDismissRequested` from `PanelSurface`, `toplevelProcess` forwarded to `PanelSurface`.
- [x] labwc `rc.xml` — W-Tab keybind updated from `rofi -show window` to `echo toggleWindowSwitcher > pillbox.fifo`.

---

## MPRIS Pill

### Data layer

- [x] `MprisProcess` — pure QML `Item`, no subprocess. Binds to `Quickshell.Services.Mpris.Mpris.players` (`ObjectModel<MprisPlayer>`). An `Instantiator` creates one `Connections` watcher per player, listening to `onPlaybackStateChanged` and `onTrackChanged`.
  - `players` — `Mpris.players` (`ObjectModel<MprisPlayer>`). Iterate in JS via `.values`.
  - `activePlayer` — selected `MprisPlayer` or `null`. Re-evaluated on every state/track change via `_selectPlayer()`: Playing > Paused > first available.
  - `signal playerUpdated(var player)` — emitted on any playback state change or track change.
  - Key lesson: `ObjectModel` has no `.length` in JS — must use `.values.length`.

### Pill

- [x] `MprisPill` — binds to `MprisProcess` (injected by `shell.qml`).
  - `isActive: bool` — true while `activePlayer` is non-null and `trackTitle` is non-empty. Persists for the duration of playback. This is the Stage 1 winner signal — MPRIS holds the winner slot in `PillController` as long as music is playing, regardless of whether the pill is visible.
  - `shouldShow: bool` — true for 3 seconds after any `playerUpdated` event. Local `Timer` restarts on each event; rapid changes extend the peek window rather than stacking. This is the Stage 2 content-driven trigger only.
  - `visualComponent` — playback state glyph (`String.fromCodePoint(0xf04b/0xf04c/0xf04d)` via `fontNerd`) + track title (`font.families: [fontMono, fontCJK]`). Title elided right.
  - Glyph fix: embedded raw Unicode bytes (copy-paste corruption) replaced with explicit `String.fromCodePoint(0xXXXX)` calls throughout MprisPill, WindowPill, and WindowSwitcherPanel.

### Infrastructure

- [x] `PillController` — `isActive` used for MPRIS at Stage 1 (`if (mprisPill && mprisPill.isActive)`), separating winner eligibility from the peek trigger. `shouldShow` on MprisPill still drives Stage 2 content-driven reveal.
- [x] `shell.qml` — `MprisProcess { id: mpris }`, `MprisPill { id: mprisPill; mprisProcess: mpris }`, `mprisPill` registered with `PillController`.
- [x] `root-processes/qmldir` — `MprisProcess 1.0 MprisProcess.qml` registered.

### CJK font fallback

- [x] `Style.qml` — added `fontCJK: "Sarasa Mono SC"` (from `ttf-sarasa-gothic`, installed). Sarasa is Iosevka + Source Han Sans — a monospace CJK font that pairs cleanly with JetBrainsMono. Not Nerd Font patched, so `fontNerd` stays as JetBrainsMono Nerd Font.
- [x] CJK fallback is handled transparently by Qt via fontconfig — `font.families` (list form) is not available in this Qt build. All text items use `font.family: Style.fontMono`; Qt asks fontconfig for missing glyphs and fontconfig resolves to Sarasa for CJK characters. `Style.fontCJK` documents the intent for when `font.families` becomes available.
