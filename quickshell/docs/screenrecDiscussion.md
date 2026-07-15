# Screenshot & Screenrec — Design Discussion

## Status: Design complete — ready to build

---

## Pre-Build Checklist

- [x] **1. Scripts audit** — check `scripts/` for reusable scripts; note what is new
- [x] **2. Reusable elements audit** — check `module-reusable-elements/` for what can be used directly
- [x] **3. Repeating element audit** — identify candidates for new reusable components
- [x] **4. Dependency audit** — check `dependency` for missing packages, add them
- [x] **5. Review reusable element candidates before building** — `MediaThumbnail.qml` and `ToastTimer.qml` both approved
- [x] **6. Prepare live system directories** — dirs at `~/Screenshots`, `~/Recordings`, `~/Recordings/Replays` (xdg-user-dirs not configured on this system; xdg-user-dir falls back to `$HOME`). Symlinks at `pillbox/media/` verified correct.
- [x] **7. Build scripts** — `helper/screenshot/pillbox-screenshot` and `helper/screenrec/pillbox-screenrec` + `pillbox-screenrec-saved` (-sc callback). Tested:
  - `screenshot screen` ✓ — emits `screenshot:saved:/path`, file verified
  - `screenshot all` ✓ — same path
  - `screenshot badmode` ✓ — emits `screenshot:error:unknown mode`, exits 1
  - `screenrec screen` start→stop via CTL FIFO ✓ — `screenrec:started` then `screenrec:stopped:/path`, GSR dead, FIFO cleaned, 585KB valid MP4
  - `screenrec` double-start guard ✓ — second instance emits `screenrec:error:already recording (pid N)`, exits 1
  - **Key fix:** watcher subshell uses `kill -0` polling loop (not `wait`) — `wait` in a subshell cannot block on a non-child PID
  - **Safety net:** `trap _emergency_stop EXIT` sends SIGINT to gsr if the script itself exits unexpectedly (QML crash, SIGKILL), preventing unbounded recording files
  - **Wayland note:** `-w focused` is X11-only; on Wayland/labwc, window mode = screen capture + `--replay` flag
  - **Region mode:** not tested interactively (requires slurp UI); tested implicitly via screenshot region path; screenrec region uses `slurp -f '%wx%h+%x+%y'` → `-w region -region WxH+X+Y`
- [x] **8. Build QML processes and wire scripts** — `ScreenshotProcess.qml`, `ScreenrecProcess.qml` in `root-processes/`; Prefs entries (`screenshotDir`, `recordingDir`, `replayDir`); FifoListener signals; shell.qml wiring; scripts symlinked to `~/.local/bin/`. Tested via FIFO with quickshell running:
  - `screenshotScreen` → `[ScreenshotProcess] saved: .../screenshot_*.png` ✓, file verified in `~/Screenshots/`
  - `screenshotAll` → same ✓
  - `screenrecStartScreen` → `[ScreenrecProcess] started`, CTL FIFO EXISTS ✓
  - `screenrecStop` → `[ScreenrecProcess] stopped: .../recording_*.mp4`, CTL FIFO cleaned, 2.3MB valid MP4 ✓

---

### Step 1 — Scripts audit (✓ complete)

`scripts/` contains:

| Script | Relevant? | Notes |
|---|---|---|
| `record-toggle.sh` | **Reference** | Existing gpu-screen-recorder toggle. Hardcoded `-w DP-3`, outputs to `~/Videos/`. Superseded by `pillbox-screenrec` for Pillbox integration. Keep as standalone utility — do not remove. **Borrow:** PID-file pattern (`echo $! > $PID_FILE` / `kill -INT $(cat $PID_FILE)`). Use `~/.local/share/pillbox/screenrec.pid` instead of `/tmp/gsr-pid`. |
| `gcal-notify.sh` | No | `notify-send` wrapper for gcal. Not relevant. |
| `focus-or-open.sh` | No | wlrctl focus helper. Not relevant. |
| `start-watchers.sh` | No | qs-watcher pre-flight. Not relevant. |
| `system-*.sh` | No | System power actions. Not relevant. |
| `calendar-toggle.sh`, `mpris-toggle.sh`, `window-switch-toggle.sh` | No | Pre-Pillbox FIFO scripts at `/tmp/qs-*`. Superseded by main FIFO. |

**New scripts to create:**

| Path | Purpose |
|---|---|
| `helper/screenshot/pillbox-screenshot` | grim capture (screen/all/region via slurp), multi-MIME wl-copy, emit filepath to stdout |
| `helper/screenrec/pillbox-screenrec` | gpu-screen-recorder start/stop (screen/region/window), daemon mode for replay, PID management, emit status lines to stdout |

---

### Step 2 — Reusable elements audit (✓ complete)

| Component | Used in | How |
|---|---|---|
| `IconButton` | ScreenshotPreview, ScreenrecToast | Button arrays (Dismiss, Copy, More; Stop, SaveReplay). Compact glyph button, correct size. |
| `PanelButton` | ControlPanel additions | Mode selector (Screen/Region/Window), Start Recording button. Has variant system (accent, critical, default). |
| `ScrollingText` | ScreenrecToast (saved state), ScreenshotPreview (filename) | Long filenames that overflow. Already handles pause-scroll-pause. |
| `TogglePair` | ControlPanel — replay toggle | On/Off toggle, variant "yesno". Disable via `enabled: false` when mode ≠ Window. |
| `SectionHeader` | ControlPanel — Screenrec section | Collapsible section heading. |
| `SectionLabel` | ControlPanel sub-labels | Small caps labels for mode/audio sub-rows. |
| `RowLabel` | ControlPanel rows | Label-left, control-right layout rows. |
| `PanelDivider` | ControlPanel | Separator before Screenrec section. |
| `PanelCard` | ControlPanel | Wraps the Screenrec section block. |

**Reference only (not used directly):**
- `HoverZone` — it's a PanelWindow for pill-zone hover. Toasts use `HoverHandler` inside their own item instead. Study the debounce timer pattern.
- `PillWindow` — structural reference for ToastWindow (corner-anchored PanelWindow).
- `PillController` — architectural reference for ToastController (aggregator pattern).
- `StatusDot` — 8px On/Off dot. Concept is right but recording dot needs custom: larger, always red, blinking. Build inline in ScreenrecToast.

---

### Step 3 — Repeating element candidates (✓ complete)

Two genuine candidates for new reusable components:

**`MediaThumbnail.qml`** — candidate for `module-reusable-elements/`

Used in both ScreenshotPreview (screenshot thumb) and potentially future ScreenrecToast saved state (video poster frame). Spec:
- Fixed-width `Rectangle` with `clip: true`, `surfaceLowColor` background, rounded corners
- `Image` inside with `PreserveAspectFit`, `fillMode`
- Filename overlay at bottom edge: semi-transparent dark backing, `Text` with `ElideMiddle`
- `TapHandler` for primary click action (caller provides callback)
- Properties: `source`, `filename`, `onThumbnailClicked`

**`ToastTimer.qml`** — candidate for `module-reusable-elements/` (or inline `QtObject`)

Both ScreenshotPreview and ScreenrecToast (saved state) share the same auto-dismiss + hover-pause pattern:
- `Timer` that auto-dismisses after N seconds
- Pauses on mouse enter, restarts from full duration on mouse leave
- Properties: `interval`, `running`; signal: `expired()`

Could be a `QtObject` each toast instantiates, binding its `HoverHandler.hovered` to the timer's `paused` property. Avoids duplicating the start/stop/reset logic in each toast module.

**Entrance animation** — *standardize as a documented spec, not a component.* QML animations are tightly coupled to the item they animate; a shared component would require complex child injection. Instead, document the standard in `components.md` and each toast implements it identically: `NumberAnimation` on `x`, slide from right, `Easing.OutCubic`, 200ms.

---

### Step 4 — Dependency audit (✓ complete)

**Missing packages — added to `dependency`:**

| Package | Provides | Needed for |
|---|---|---|
| `wl-clipboard` | `wl-copy`, `wl-paste` | Clipboard operations in `pillbox-screenshot` (auto-copy PNG, multi-MIME) |
| `xdg-user-dirs` | `xdg-user-dir` | `install.sh` media directory resolution |

All other screenshot/screenrec dependencies already present: `grim`, `slurp`, `gpu-screen-recorder`, `xdg-utils` (xdg-open), `imv`.

---

### Step 5 — Review new reusable element candidates

**Pending user sign-off before building.**

The two candidates proposed in Step 3:
1. `MediaThumbnail.qml` — thumbnail + filename overlay, reused across screenshot/video toasts
2. `ToastTimer.qml` — auto-dismiss + hover-pause timer object, shared across all toast modules

Review the specs above and confirm, modify, or drop before build starts.

---


## Toolchain (decided)

| Tool | Role |
|---|---|
| `grim` | Screenshot capture (wlr-screencopy, no portal) |
| `slurp` | Interactive region selection |
| `gpu-screen-recorder` (VA-API, AMD) | Screen recording + replay buffer |

Qt native screen capture: rejected. Mandatory portal dialog is a non-starter for shell-level keybinds.

---

## Scope Overview

| Feature | Status |
|---|---|
| Screenshot — whole screen / all screens / region | In discussion |
| Screenrec — 1 screen only | In discussion |
| Screenrec — region pick | TBD |
| Replay buffer | TBD |
| Audio capture | TBD |

---

## 1. Screenshot

### 1A. Shot Modes

Three capture targets:
- **All screens** — `grim` with no `-o` flag (captures every output into one image)
- **1 screen** — `grim -o <output-name>` (primary or active output)
- **Region pick** — `grim -g "$(slurp)"` (slurp opens an interactive crosshair selection)

#### Trigger path options

**Path 1 — Pure keybind (no quickshell involvement)**
- `rc.xml` keybinds call a shell script directly
- Script runs `grim` with the appropriate flags, saves to a timestamped file
- Quickshell is completely uninvolved
- Simplest to implement; no feedback in the pill/panel
- Matches the user's existing setup

**Path 2 — rc.xml + FifoListener**
- `rc.xml` keybinds write FIFO commands (`screenshotAll`, `screenshotScreen`, `screenshotRegion`)
- `FifoListener.qml` dispatches to a `ScreenshotProcess` which runs `grim` as a subprocess
- Quickshell owns the capture — can show pill feedback (flash, filename), trigger post-shot UI, log to image bank
- More integration surface; required if post-shot preview/picker (1B) is desired

**Path 3 — GUI trigger**
- A panel or special surface presents shot mode buttons
- User picks mode from UI rather than memorising keybinds
- Constraint: **no new panel** — would either:
  - Share an existing panel as a new tab (e.g., Control panel gets a "Capture" tab)
  - Get special treatment like the Visualiser/WindowSwitcher — its own `PanelWindow` outside the nav row, summoned by a dedicated keybind or FIFO command, dismissed after the shot is taken

**Decision: Path 2 — rc.xml + FifoListener + script backend.**

FIFO commands:
- `screenshotRegion` — region pick
- `screenshotScreen` — primary screen only
- `screenshotAll` — all screens
- `screenshotUI` — open NotificationPanel on Screenshots tab

FifoListener dispatches to `ScreenshotProcess`, which spawns `pillbox-screenshot <mode>`. Script owns the full capture pipeline. Quickshell reads stdout for the saved filepath and triggers the preview toast + image bank update.

---

### 1B. Post-Shot — Preview & Picker

#### Preview — `ScreenshotPreview.qml` toast module (index 0)

**Not PanelSurface.** WindowSwitcherPanel is content loaded *by* PanelSurface — it is not its own window. PanelSurface is a fullscreen overlay with exclusive keyboard focus, unsuitable for a passive corner preview.

The screenshot preview lives in `module-toasts/ScreenshotPreview.qml`. It is a self-deciding toast module hosted by `ToastWindow` in the bottom-right corner. Non-blocking, no keyboard focus grab, auto-dismisses.

**Trigger:** `ScreenshotProcess` emits a signal when a capture succeeds (filepath received from script stdout). `ScreenshotPreview` watches this and sets `shouldShow: true`.

**Dismiss conditions:**
- Auto-dismiss after N seconds (TBD — 5s?)
- User taps Dismiss action
- User taps any other action (copy, open) — closes after acting

**Actions (decided):**
- **Dismiss** — hide preview, file stays in image bank
- **Open UI** — calls `screenshotUI` FIFO → opens NotificationPanel on Screenshots tab
- **Copy image** — `wl-copy -t image/png < file` — raw PNG bytes on clipboard
- **Copy path** — `wl-copy /path/to/file` — text path on clipboard

**Multi-MIME note:** copy image and copy path are separate actions (two distinct buttons). A single clipboard entry offering both simultaneously requires a multi-MIME helper — will be provided by `pillbox-screenshot` script for the auto-copy-on-region-pick case. Manual copy buttons in the preview use separate `wl-copy` calls.

**Auto-copy on region pick:** `pillbox-screenshot region` auto-copies `image/png` immediately after capture (before preview appears). Preview's "Copy image" button re-copies on demand. Other modes (screen, all) do not auto-copy.

---

### ScreenshotPreview — Appearance & Interaction Spec

#### Surface

- Draws its own background — `pillBgColor` rounded rectangle, same visual language as pills
- `border.color: Style.borderFaintColor`, `border.width: Style.pillBorderWidth`
- Radius: TBD (pill radius or panel element radius — settle at build time)
- ToastWindow itself is fully transparent — no surface of its own

#### Layout: two-column RowLayout

```
┌──────────────────────────────────────┐
│  ┌──────────────┐  [ × ]            │
│  │              │  [ copy image ]   │
│  │  thumbnail   │  [ ⋮  more   ]   │
│  │              │                   │
│  │ filename.png │                   │
│  └──────────────┘                   │
└──────────────────────────────────────┘
```

**Column 1 — Thumbnail**
- Fixed size (width TBD; height derived from screenshot's actual aspect ratio using `PreserveAspectFit` — full screenshot visible, letterboxed if needed, not cropped)
- Background: `surfaceLowColor` (visible during image load and as letterbox fill)
- Radius: matches surface radius
- `clip: true`

*Filename overlay* — sits at bottom edge of thumbnail:
- Semi-transparent dark backing (`Qt.rgba(0,0,0,0.45)` or similar) so text is legible against any screenshot content
- Filename text, truncated (`elide: Text.ElideMiddle` — keeps extension visible), `QQC.ToolTip` shows full name on hover
- `font.pixelSize: Style.fontSizeSubtle`, `color: white` (absolute, not a theme token — always on dark backing)
- Click: copy filepath (`wl-copy /path/to/file`) + dismiss

*Thumbnail click (primary action):*
- `xdg-open file` — opens in user's default PNG handler (image viewer, file manager, editor)
- Fires multi-MIME script: puts both `image/png` (pixel data) and `text/plain` (filepath) on clipboard simultaneously
- Dismiss
- Intent: "I want to work on this now" — the most common post-shot action

**Column 2 — Vertical button array**

Three `IconButton`-sized buttons, top-aligned:

| # | Glyph | Action | Dismisses? |
|---|---|---|---|
| 1 | × | Dismiss only | Yes |
| 2 | clipboard/copy glyph | Copy image — `wl-copy -t image/png < file` (pixel data) | No |
| 3 | ⋮ or › glyph | Open image bank (`screenshotUI` FIFO) | Yes |

Button 2 does not dismiss — user may copy image then switch to Discord to paste, and still want the preview available.

**Right-click anywhere on ScreenshotPreview → dismiss.**

#### Sizing

- Total width: `Screen.width * 0.12` — starting point, adjust if needed after seeing it live
- Height: content-driven from thumbnail height + padding
- Thumbnail width: fills column 1. Height derived from the screenshot's actual aspect ratio via `image.sourceSize` — `thumbHeight = thumbWidth * (sourceSize.height / sourceSize.width)`. `PreserveAspectFit` as fillMode.

#### Auto-dismiss

- 5 seconds from appearance (or from last mouse-leave)
- **Timer pauses while mouse is inside the toast module.** `HoverHandler` on the root item detects enter/leave. On enter: stop timer. On leave: restart timer from 0 (full 5s again, not resume from where it left).
- Once dismissed by any means, the preview is gone — not recoverable. The image bank (Screenshots tab in NotificationPanel) is the persistent record.
- This hover-pause pattern is **standardized across all toast modules**.

*Implementation note (TBD at build time):* hover detection and timer pause can live either in each toast module independently, or in ToastWindow (which exposes a `mouseInside` property that modules bind to). Decide at build time based on what's cleaner.

#### Entrance animation (standardized for all toast modules)

- **Slide in from the right** — toast starts off-screen to the right, translates to its resting position
- `NumberAnimation` on `x` (or `transform: Translate`), easing TBD (likely `Easing.OutCubic`)
- Duration TBD at build time (150–250ms)
- All future toast modules use the same entrance. ToastWindow is responsible for triggering the animation when a module becomes visible — or each module triggers its own. Decide at build time.

#### Image bank — Screenshots tab in NotificationPanel

`NotificationPanel` gains a second tab via `PanelTabBar`: "Notifications" / "Screenshots".

Screenshots tab — scrollable card list, visually identical to notification cards:
- Thumbnail left, filename + timestamp right
- Per-card actions: Copy image, Copy path, Open, Delete
- No "Clear all" — per-card delete only

`ScreenshotProcess` maintains the in-memory list, scanned from the save folder on startup and updated on each new capture.

**Save folder:** `$(xdg-user-dir PICTURES)/Screenshots/` — resolved at install time, symlinked to `~/.config/pillbox/media/Screenshots`. `ScreenshotProcess` reads the path from Prefs (`screenshotDir`), defaulting to the symlink. User can override via Settings panel (future).

**FIFO `screenshotUI`:** opens NotificationPanel pre-landed on Screenshots tab.

---

---

## Toast System — Architecture (decided)

### The third UI tier

The shell now has three distinct UI tiers:

| Tier | Example | Invocation | Exclusion | Smart/Dumb |
|---|---|---|---|---|
| **Pill** | NotificationPill, MprisPill | Self-triggered, data-driven | One at a time (priority) | Smart content, dumb container |
| **Panel** | NotificationPanel, SettingsPanel | User-deliberate only | One at a time | Dumb content, smart container |
| **Toast** | ScreenshotPreview, ScreenrecToast | Self-triggered, data-driven | None — coexist | Smart content, dumb container |

Toasts are in between: they appear automatically like pills, but can coexist (no mutual exclusion), are larger and actionable (unlike pills), and are not user-invoked (unlike panels).

---

### ToastWindow (`module-reusable-elements/ToastWindow.qml`)

**Dumb container. No opinion on content, timing, or visibility.**

- `PanelWindow` anchored `bottom: true`, `right: true`
- Margins: `Screen.height * 0.02` for both bottom and right — same token as pill's top margin. Consistent visual corner weight across the screen.
- Root content: `ColumnLayout` — toast modules stack vertically
- `implicitWidth`: fixed preferred width (TBD at appearance time, likely `Screen.width * 0.15`)
- `implicitHeight`: driven by ColumnLayout's implicitHeight — sum of visible modules only. Collapses to zero when nothing is showing.
- `visible`: bound to `ToastController.shouldShow`
- In `module-reusable-elements/`, same as PillWindow and PanelSurface

**Processes are injected into ToastWindow by shell.qml and forwarded to each module** — same pattern as PanelSurface forwarding processes to panels.

---

### ToastController (`module-reusable-elements/ToastController.qml`)

**Pure `QtObject`. Aggregates shouldShow across all toast modules.**

Mirrors PillController in role but with a different job:
- PillController: resolves *which one* pill wins (mutual exclusion, priority)
- ToastController: resolves *whether any* toast is showing (OR aggregation, no exclusion)

```qml
QtObject {
    property var screenshotPreview: null
    property var screenrecToast:    null

    readonly property bool shouldShow:
        (screenshotPreview ? screenshotPreview.shouldShow : false) ||
        (screenrecToast    ? screenrecToast.shouldShow    : false)
}
```

No priority system. No competition. Modules coexist freely.

---

### `module-toasts/` directory

New directory, same level as `module-pills/` and `module-panels/`. Each file is a toast module.

**Current roster:**

| File | Index | Persistent? | Status |
|---|---|---|---|
| `ScreenshotPreview.qml` | 0 | No — transient, auto-dismisses | Planned |
| `ScreenrecToast.qml` | 1 | Yes — shows for duration of recording | Planned |

**Index = fixed row position in ToastWindow's ColumnLayout.** Index 0 is at the top (furthest from corner); highest index is closest to the bottom-right corner.

**Ordering rationale:**
- Screenrec (index 1) sits at the bottom, closest to the corner — it's a persistent status anchor while recording is active
- Screenshot preview (index 0) floats above it temporarily when a capture is taken
- Both can show simultaneously (e.g., take a screenshot while recording)

**Future:** index order will be wired to Prefs so users can adjust. Not now.

**Each toast module owns:**
- `shouldShow: bool` — read by ToastController
- Its own data source watch (ScreenshotProcess, ScreenrecProcess etc.)
- Its own appear/dismiss logic and auto-dismiss timer if applicable
- Its own `implicitHeight` (drives its slot in the ColumnLayout)
- When `visible: false`, ColumnLayout collapses the slot to zero — no gap

---

### Directory structure additions

```
quickshell/
├── module-toasts/              ← NEW — same level as module-pills/, module-panels/
│   ├── ScreenshotPreview.qml   ← transient, index 0
│   ├── ScreenrecToast.qml      ← persistent indicator, index 1
│   └── qmldir
├── module-reusable-elements/
│   ├── ToastWindow.qml         ← NEW — dumb container, bottom-right PanelWindow
│   ├── ToastController.qml     ← NEW — aggregates shouldShow
│   └── ...
├── root-processes/
│   ├── ScreenshotProcess.qml   ← NEW — runs pillbox-screenshot, manages image bank
│   └── ...
├── helper/
│   └── screenshot/
│       └── pillbox-screenshot  ← NEW — bash script: slurp→grim→multi-MIME wl-copy
```

---

## 2. Screenrec

### 2A. Intent

Screen recording has two distinct user modes — casual/general recording ("I want to capture what I'm doing") and gaming mode ("I want to keep the last N seconds of this game"). These two modes have fundamentally different setups, triggers, and UX needs. Mixing them into one UI flow creates complexity; keeping them explicitly separated gives the user clear mental models.

**Core principle:** the user makes their mode choice once (in the Control panel) before recording starts. Once recording is active, the Control panel is gone and the in-session controls live entirely in `ScreenrecToast`.

---

### 2B. The Three Modes

| Mode | gpu-screen-recorder flag | Use case | Replay possible? |
|---|---|---|---|
| **Screen** | `-w screen` (primary output) | General/desktop recording | No |
| **Region pick** | `-cr x,y,w,h` (from slurp) | Cropped area of screen | No |
| **Window (focused)** | `-w focused` | Gaming / single-app capture | **Yes** |

**Screen mode** captures the primary output. No region selection, no focus tracking. Simplest path.

**Region pick mode** requires the user to draw a rectangle before recording starts. This uses the same `slurp` flow as screenshot region — the user draws a box, its coordinates are passed to gpu-screen-recorder via `-w region -region WxH+X+Y` (slurp output format: `slurp -f '%wx%h+%x+%y'`). The recording is then a fixed crop of those screen coordinates regardless of what window is in that area. Suitable for cropping a secondary monitor, a canvas, a reference stream.

**Window (focused) mode** uses `-w focused` — gpu-screen-recorder captures whichever window has focus at the moment recording starts. This is the dedicated gaming mode: launch game → focus it → start recording. If the user alt-tabs out, the window's content continues being captured (gpu-screen-recorder follows the texture, not the position). This is also the only mode where replay makes sense, because the user typically can't predict the epic moment — they want to "save the last 30s" reactively.

---

### 2C. Replay Buffer

Replay is **opt-in, arm-on-demand, window mode only.**

**How it works:** gpu-screen-recorder's `-r <seconds>` flag keeps a rolling in-memory buffer. Nothing is written to disk until the user triggers save-replay. The buffer is entirely in GPU VRAM during capture (DMA-BUF path) — zero CPU cost and zero disk cost until save.

**Why arm-on-demand vs always-on:**
- Always-on replay would mean the daemon needs to be running with a recording target at all times, even during desktop use. This causes unnecessary GPU work and makes mode selection complex.
- Arm-on-demand: user opens Control panel → sets Window mode → toggles Replay on → starts recording. The replay buffer starts when recording starts, stops when recording stops.
- If the user doesn't need replay, they leave the toggle off and window mode behaves identically to screen mode (just with window focus tracking).

**Replay buffer duration:** TBD — likely 30s default, user-configurable in Prefs later.

**Important pitfall — daemon pre-run requirement:** gpu-screen-recorder's replay functionality requires the daemon (`gpu-screen-recorder -d`) to already be running with `-r` before recording starts. You cannot add replay to an in-progress recording. The daemon must be started with replay enabled from the beginning. This means: if user wants replay, the script starts the daemon with `-r <seconds>` when they arm recording. If they don't want replay, no `-r` flag.

---

### 2D. User Decision Points

There are exactly three moments where the user has to make a choice:

**Decision 1: Pre-session setup (Control panel)**
- What mode? Screen / Region pick / Window
- What audio? None / System / Mic / Both (for now: no audio — deferred)
- Replay? (only enabled/clickable when mode = Window)

**Decision 2: Arm the gaming session (replay toggle, Window mode)**
- User launches game, focuses it, arms replay by toggling it on in Control panel before starting
- Once recording starts, Control panel is dismissed — no way to change these settings mid-session

**Decision 3: In-session control (ScreenrecToast)**
- Stop recording (ends capture, saves file, transitions to saved state)
- Save replay (saves last N seconds without stopping the recording — can trigger multiple times)
- Pause/resume (if desired — FIFO-backed)

The user never needs to touch a terminal or remember a command. Keybinds in rc.xml send the FIFO signals.

---

### 2E. FIFO Interface

| Command | Effect |
|---|---|
| `screenrecStartScreen` | Start recording in screen mode (no region pick, no window tracking) |
| `screenrecStartRegion` | Invoke slurp for region pick, then start recording in that crop |
| `screenrecStartWindow` | Start recording in window (focused) mode |
| `screenrecStop` | Stop active recording, save file, emit saved signal |
| `screenrecSaveReplay` | Save replay buffer segment (window mode + replay armed only) |
| `screenrecPause` | Pause active recording |
| `screenrecResume` | Resume paused recording |

**`screenrecStartRegion` pitfall — panel dismiss timing:** The user selects Region mode in the Control panel, then presses a keybind (or clicks a button). That button sends `screenrecStartRegion` to FIFO. The FIFO listener in Quickshell must:
1. Dismiss the panel (PanelSurface hides)
2. **Wait for the panel to fully disappear** (surface unmapped)
3. *Then* launch slurp for region pick

If slurp launches while the panel is still visible, the panel steals keyboard/pointer focus and the user can't draw the region rectangle. The panel UI will be captured in the recording crop as well.

**Fix:** The `ScreenrecProcess` listens for a `panelDismissed` signal (or a short timer — e.g., 200ms) before invoking slurp. The exact mechanism (signal vs timer) is determined at build time based on what Quickshell exposes cleanly.

---

### 2F. Control Panel Additions

The existing Control panel gets a **Screenrec section** added. It appears below the existing audio/network section.

**Mode selector — horizontal button array:**
```
[ Screen ]  [ Region ]  [ Window ]
```
- These function like radio buttons — one active at a time, highlighted when selected
- Clicking a mode button: sets the mode, does NOT start recording immediately
- The "Start" action is a separate button (or keybind) so the user can configure without accidentally triggering

**Audio selector — horizontal button array (deferred, included for completeness):**
```
[ None ]  [ System ]  [ Mic ]  [ Both ]
```
- Defaulted to None for now. Section may be hidden until audio is implemented.

**Replay toggle:**
```
[ ⬤ Replay  30s ]
```
- Toggle button, grayed out and unclickable unless mode = Window
- When grayed out, tooltip (or label): "Only available in Window mode"
- When enabled: shows buffer duration (30s default). Long-press or secondary button for duration setting (deferred)

**Start Recording button:**
- Primary action at bottom of Screenrec section
- Text changes based on mode: "Start — Screen", "Pick Region & Start", "Start — Window"
- Clicking Start:
  - For Screen / Window: fires the appropriate FIFO command, panel dismisses
  - For Region: fires `screenrecStartRegion`, panel dismisses, then slurp runs (see timing pitfall above)

---

### 2G. `ScreenrecToast.qml` (index 1 in ToastWindow)

The persistent in-session indicator. Lives at index 1 (bottom row, closest to corner) — it's a status anchor that should feel stable while recording is active. Index 0 (ScreenshotPreview) floats above it.

**Two states:**

#### State 1: Recording active (persistent, never auto-dismisses)

```
┌────────────────────────────────────┐
│  ● 00:03:42   [ ■ Stop ]  [ ↓ ]  │
└────────────────────────────────────┘
```

- `●` — pulsing red dot (same animation token as critical dot, faster blink)
- `00:03:42` — elapsed timer, counts up from 0:00, monospaced (`fontMono`)
- `[ ■ Stop ]` — stops recording + saves file + transitions to State 2
- `[ ↓ ]` — Save Replay button; **only visible when replay is armed**; sends `screenrecSaveReplay`; does NOT stop recording; on press: brief visual flash to confirm ("Saved!") then returns to normal
- Background: `criticalBgColor` or a dedicated `recordingBgColor` (TBD at build — criticalBgColor may be fine since red = "recording in progress" is a universal signal)

When the `[ ↓ ]` button is triggered, the button momentarily shows a checkmark glyph for ~1s then reverts. This confirms the replay clip was saved without modal interruption.

#### State 2: Saved (transient, auto-dismisses)

```
┌─────────────────────────────────────────┐
│  [filename.mp4]  3:42  [ play ] [ ⋮ ]  │
└─────────────────────────────────────────┘
```

- Filename (elided middle), recording duration
- `[ play ]` / open glyph: `xdg-open file`
- `[ ⋮ ]` / more glyph: opens a TBD media bank panel (future — no panel exists yet; for now this copies the filepath)
- Auto-dismisses after 8s (longer than screenshot — video files take longer to decide what to do with)
- Hover-pause: same pattern as ScreenshotPreview — mouse inside pauses auto-dismiss timer, resets on leave
- Right-click to dismiss
- Background: `pillBgColor` — back to neutral, recording is done

**`shouldShow` logic:**
```qml
readonly property bool shouldShow: _recording || _showingSaved
```
- `_recording`: true while gpu-screen-recorder process is active
- `_showingSaved`: true from stop until auto-dismiss or user dismiss
- Both can be false simultaneously (idle state) — ScreenrecToast contributes no height to ToastWindow

---

### 2H. Script backend — `pillbox-screenrec`

Mirrors `pillbox-screenshot` in structure. Quickshell's `ScreenrecProcess` spawns this script and reads its stdout for status signals.

**Responsibilities:**
- Start gpu-screen-recorder with correct flags based on FIFO command received
- For region mode: run slurp first, parse output, pass `-cr x,y,w,h` to gpu-screen-recorder
- Manage gpu-screen-recorder daemon lifecycle (start on arm, stop on stop command)
- Emit status lines to stdout: `recording:started`, `recording:stopped:/path/to/file.mp4`, `replay:saved:/path/to/clip.mp4`
- Handle save folder: resolved from Prefs (`recordingDir` / `replayDir`), defaulting to `~/.config/pillbox/media/Recordings` and `~/.config/pillbox/media/Replays` (symlinks to XDG Videos subdirs, created by install.sh)

**Daemon vs direct invocation:**
- gpu-screen-recorder daemon mode (`gpu-screen-recorder -d`) is required for replay buffer
- For non-replay modes, direct invocation (`gpu-screen-recorder <flags>`) is simpler and doesn't leave a daemon running between sessions
- Script handles both: if replay is armed (passed as argument), use daemon + ctl; otherwise invoke directly

---

### 2I. Directory additions

```
quickshell/
├── module-toasts/
│   ├── ScreenrecToast.qml     ← index 1, persistent during recording
│   └── ...
├── root-processes/
│   └── ScreenrecProcess.qml   ← NEW — manages daemon, reads stdout signals
├── helper/
│   └── screenrec/
│       └── pillbox-screenrec  ← NEW — bash script: mode dispatch, slurp, daemon ctl
```

### 2J. Prefs entries (to add at build time)

Three new keys in `prefs.json`, all user-configurable via Settings panel (future):

| Key | Default value | Used by |
|---|---|---|
| `screenshotDir` | `~/.config/pillbox/media/Screenshots` | ScreenshotProcess, pillbox-screenshot |
| `recordingDir` | `~/.config/pillbox/media/Recordings` | ScreenrecProcess, pillbox-screenrec |
| `replayDir` | `~/.config/pillbox/media/Replays` | ScreenrecProcess, pillbox-screenrec |

The defaults resolve through the `pillbox/media/` symlinks created by `install.sh`. Changing a Prefs value redirects saves to the new folder — symlinks are unaffected, XDG dirs remain untouched. If a user uninstalls, removing `~/.config/pillbox/media/` drops the symlinks only; their actual media in `~/Pictures/Screenshots/` etc. is never touched.

**Temp/operational files:** `~/.local/share/pillbox/` (existing convention — FIFO, PID). Truly ephemeral script scratch (if ever needed) uses `$XDG_RUNTIME_DIR/pillbox/` — created by scripts at runtime, no install.sh setup needed, cleaned on logout automatically.

---

## 3. Replay Buffer

Covered inline in section 2C above. Replay is not a standalone module — it is an optional mode of Screenrec (window mode only, arm-on-demand). No separate FIFO process or UI module needed.

---

## 4. Audio Capture (deferred)

gpu-screen-recorder `-a` flag: PipeWire/PulseAudio audio source. Options: None (default), system audio (default sink monitor), mic, both.

Audio is intentionally deferred for the initial build. The Control panel audio array is specced (see 2F) but hidden until implemented. All FIFO commands and script backend are designed to accept an audio parameter without breaking when it's absent.

Audio capture applies to Screenrec only — not to screenshots, not to replay (replay inherits whatever audio flags the parent recording has).
