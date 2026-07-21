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

**FIFO `screenshotUI`:** opens NotificationPanel pre-landed on Screenshots tab. Implemented via `notificationInitialTab` on PanelSurface (see D5).

#### Image bank scan implementation (ready to build)

Pattern mirrors `WallpaperProcess` image/video scan exactly. Key details:

- **`find -printf "%T@\t%p\n"`** — outputs `mtime_epoch<TAB>path` per file, one pass
- **`StdioCollector`** (not SplitParser) — collects full output, processes in `onStreamFinished`
- **Sort by mtime descending** (newest first) in JS after parsing
- **Cap at 200 entries** for Repeater performance
- **Scan in `Component.onCompleted`** — auto-runs on Quickshell startup, persists because `ScreenshotProcess` is a root-process (always alive). Panel open/close does not re-scan; data lives in the process.
- **Live captures** (`notifyExternalSave`, `screenshotSaved`) unshift to the front as they do now. No dedup needed — startup scan runs before user can take a screenshot.

```qml
// In ScreenshotProcess.qml — add alongside existing _proc
Process {
    id: _scanProc
    command: ["find", root._dir, "-maxdepth", "1", "-type", "f",
              "-name", "*.png", "-printf", "%T@\\t%p\\n"]
    stdout: StdioCollector {
        onStreamFinished: {
            var entries = []
            text.split("\n").forEach(function(line) {
                line = line.trim()
                if (line === "" || !line.includes("\t")) return
                var tab  = line.indexOf("\t")
                var ts   = parseFloat(line.slice(0, tab)) * 1000
                var path = line.slice(tab + 1)
                entries.push({ path: path, name: path.split("/").pop(), timestamp: ts })
            })
            entries.sort(function(a, b) { return b.timestamp - a.timestamp })
            root.screenshots = entries.slice(0, 200)
            console.log("[ScreenshotProcess] scanned:", entries.length, "screenshots")
        }
    }
    onExited: function(code, signal) {
        if (code !== 0)
            console.log("[ScreenshotProcess] scan failed:", code, "dir:", root._dir)
    }
}
// In Component.onCompleted, after resolving _dir: _scanProc.running = true
```

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

> **⚠ STALE CODE — DO NOT USE AS REFERENCE.**
> The original 2A–2J design and the code it produced (`helper/screenrec/pillbox-screenrec`, `quickshell/root-processes/ScreenrecProcess.qml`, the ControlPanel screenrec section) are superseded by the redesign below. The CTL FIFO control mechanism, the start/stop gsr model, and the old FIFO commands are all obsolete. Wrapper scripts (`pillbox-screenshot-region`, `pillbox-screenrec-region`) remain valid. Post-recording UI (`ScreenrecToast.qml`) spec in section 2G is still the target — the interface that feeds it will change.

---

### 2A. Two Operational Modes

The user selects one mode from the ControlPanel. The choice is saved in Prefs and persists across sessions. Modes are **mutually exclusive** — switching while recording is blocked in the UI.

| Mode | Description |
|---|---|
| **A — One-shot** | gsr spawns on demand. Records until stopped. Any capture source including region. No replay buffer. |
| **B — Replay (Persistent)** | gsr starts at Quickshell startup and runs indefinitely. Rolling replay buffer always hot. Recording-to-file toggled via signal. Screen source only. |

---

### 2B. One-Shot Mode (A)

gsr spawns when the user starts recording, exits when stopped.

**gsr invocation:**
```sh
gpu-screen-recorder \
    -w <source> \           # screen | region (+ -region WxH+X+Y) | monitor name (e.g. DP-1)
    -f 60 \
    -c mp4 \
    -o "$RECORDING_DIR/recording_TIMESTAMP.mp4" \
    -sc pillbox-screenrec-saved
```

**Signal control:**
- Stop + save: `SIGINT`
- Pause/unpause: `SIGUSR2`

No replay buffer. Source can be anything gsr supports.

---

### 2C. Replay / Persistent Mode (B)

gsr starts in `ScreenrecProcess` `Component.onCompleted` and stays alive until Quickshell exits.

**gsr invocation:**
```sh
gpu-screen-recorder \
    -w screen \
    -f 60 \
    -c mp4 \
    -r <replayBufferSecs> \     # Prefs: replayBufferSecs, default 300 (5 min)
    -bm cbr -q 40000 \          # CBR 40 Mbps — man page recommended value for replay
    -o "$REPLAY_DIR" \          # directory: replay clips (SIGUSR1, SIGRTMIN+N) save here
    -ro "$RECORDING_DIR" \      # directory: toggle-recordings (SIGRTMIN) save here
    -sc pillbox-screenrec-saved
```

**Signal → action:**

| Signal | Effect |
|---|---|
| `SIGRTMIN` | Toggle recording to `-ro` dir (start if idle, stop + save if active) → `-sc` fires type "regular" |
| `SIGUSR1` | Save full replay buffer to `-o` dir → `-sc` fires type "replay" |
| `SIGRTMIN+1` | Save last 10 s |
| `SIGRTMIN+2` | Save last 30 s |
| `SIGRTMIN+3` | Save last 60 s |
| `SIGRTMIN+4` | Save last 5 min |
| `SIGRTMIN+5` | Save last 10 min |
| `SIGRTMIN+6` | Save last 30 min |
| `SIGINT` | Emergency stop — exits gsr WITHOUT saving buffer |

> **SIGUSR2 (pause) is NOT supported in replay mode.** The gsr man page explicitly states "not for streaming/replay". It is wired in the CTL loop for completeness but is a no-op when gsr runs as a replay daemon. Only valid in oneshot mode.

Switching Replay → One-shot: SIGINT stops gsr, one-shot mode takes over on next start. Switching back: restarts persistent gsr.

---

### 2D. Keybind Behavior

Both keybinds are mode-aware.

| Keybind | One-shot mode (A) | Replay mode (B) |
|---|---|---|
| **W-S-r** | Toggle screen recording (start / stop) | `SIGRTMIN` — toggle recording to file |
| **W-S-e** | Invoke slurp picker → one-shot region recording | Save last N seconds (Prefs: `replaySaveDefaultSecs`, default 30 s) |

W-S-e calls `pillbox-screenrec-region` in one-shot mode (slurp runs as direct labwc child — pointer grab works). In replay mode it sends `screenrecSaveReplay` (or `screenrecSaveReplay:30`) to FIFO.

> ~~**Gap (not yet implemented):** W-S-e is currently mode-unaware — rc.xml always runs `pillbox-screenrec-region` regardless of `recMode`. In replay mode it should instead write `screenrecSaveReplay:N` to the FIFO. Needs a thin mode-aware wrapper script (rc.xml cannot query Prefs state directly).~~ **Fixed** — `pillbox-screenrec-e` reads `recMode` and `replaySaveDefaultSecs` from `~/.config/pillbox.conf` (Qt Settings INI). Single mode: runs slurp → `screenrecStartRegionWith:COORDS`. Replay mode: writes `screenrecSaveReplay:N` to FIFO. rc.xml W-S-e updated to call `pillbox-screenrec-e`.

---

### 2E. Script Architecture

**`pillbox-screenrec`** — full rewrite needed.

Invocation: `pillbox-screenrec <oneshot|replay> [--source <spec>] [--region WxH+X+Y] [--fps N] [--dir <dir>] [--replay-dir <dir>] [--replay-secs N]`

**In `oneshot` sub-mode:**
1. Build gsr command with `-w <source>` (plus `-region` if source=region)
2. Launch gsr, emit `screenrec:started` once alive
3. Create notify FIFO (`screenrec-notify`), start background reader forwarding `-sc` callbacks to stdout: `screenrec:saved:PATH:TYPE`
4. CTL FIFO commands: `stop` → `SIGINT`, `pause` → `SIGUSR2`
5. On gsr exit: emit `screenrec:gsr:exited`, cleanup

**In `replay` sub-mode:**
1. Build gsr command with `-r`, `-bm cbr`, `-o` (replay dir), `-ro` (recordings dir)
2. Launch gsr, emit `screenrec:started` once alive
3. Same notify FIFO reader as oneshot
4. CTL FIFO commands: `toggleRec` → `SIGRTMIN`, `saveReplay` → `SIGUSR1`, `saveReplay:30` → `SIGRTMIN+2`, `saveReplay:60` → `SIGRTMIN+3`, `saveReplay:300` → `SIGRTMIN+4`, `pause` → `SIGUSR2`, `stop` → `SIGINT`
5. On gsr exit: emit `screenrec:gsr:exited`, cleanup

**`pillbox-screenrec-saved`** — rewrite needed.
Currently writes to a temp file. New behaviour: write to notify FIFO:
```sh
NOTIFY_FIFO="$HOME/.local/share/pillbox/screenrec-notify"
[ -p "$NOTIFY_FIFO" ] && echo "saved:$1:$2" > "$NOTIFY_FIFO"
```

**`pillbox-screenrec-region`** — unchanged. Calls slurp (as direct labwc child), writes `screenrecStartRegionWith:WxH+X+Y` to pillbox FIFO. Only used in one-shot mode.

---

### 2F. QML Architecture

**`ScreenrecProcess.qml`** — full rewrite needed.

```qml
// Mode (read from Prefs, persisted)
property string recMode: "oneshot"   // "oneshot" | "replay"

// State
property bool   active:    false     // gsr process is alive
property bool   recording: false     // currently writing to file
property string lastPath:  ""

// Signals (unchanged — ScreenrecToast still listens to these)
signal recordingStarted()
signal recordingStopped(string path)
signal replaySaved(string path)
signal recordingError(string reason)

// Public API (replaces startScreen / startRegion / stop)
function toggle()              // oneshot: start/stop; replay: SIGRTMIN via CTL FIFO
function saveReplay()          // SIGUSR1
function saveReplaySeconds(n)  // SIGRTMIN+2..+4 based on n
function pause()               // SIGUSR2
function emergencyStop()       // SIGINT
function startRegionWith(coords) // one-shot region start (called by FifoListener)
function notifyExternalSave(path) // still needed for screenshot — not screenrec
```

In replay mode: `Component.onCompleted` starts gsr immediately.
In one-shot mode: gsr spawns on first `toggle()` call.

**`FifoListener.qml`** — update commands:
- Remove: `screenrecStartScreen`, `screenrecStartRegion`, `screenrecStop`, `screenrecSaveReplay`, `screenrecToggleScreen`
- Keep: `screenrecStartRegionWith:COORDS` (from `pillbox-screenrec-region` wrapper)
- Add: `screenrecToggle`, `screenrecSaveReplay`, `screenrecSaveReplay:N`, `screenrecEmergencyStop`, `screenrecSetMode:oneshot|replay`

**`shell.qml`** — update handlers to match new API.

---

### 2G. ScreenrecToast — Spec (target unchanged)

The toast spec from the original plan remains the target. Two states:

**State 1 — Recording active (persistent):**
```
┌────────────────────────────────────┐
│  ● 00:03:42   [ ■ Stop ]  [ ↓ ]  │
└────────────────────────────────────┘
```
- Pulsing red dot, elapsed timer (monospaced), Stop button, Save Replay button (replay mode only)
- Background: `criticalBgColor`

**State 2 — Saved (auto-dismisses after 8 s, hover-pause):**
```
┌─────────────────────────────────────────┐
│  [filename.mp4]  3:42  [ play ] [ ⋮ ]  │
└─────────────────────────────────────────┘
```
- Filename (elide middle), duration, open button, more button
- Background: `pillBgColor`

`shouldShow: _recording || _showingSaved`

The toast receives its data from `ScreenrecProcess` signals — these signals are unchanged, so the existing `ScreenrecToast.qml` stub can remain as-is until the backend is ready.

---

### 2H. ControlPanel UI (redesigned — PanelCard single-row layout)

Old layout (PanelButton grid + two RowLayouts) is superseded by the design below.

```qml
PanelCard {
    Layout.fillWidth: true

    // Row 1 — SectionHeader (collapsible)
    SectionHeader {
        Layout.fillWidth: true          // tap target spans full card width
        // implicitWidth: content-driven (arrow + label text)
        text:      "Screen Recorder"
        collapsed: root._recCollapsed
        onToggled: root._recCollapsed = !root._recCollapsed
    }

    // Row 2 — controls (hidden when collapsed)
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.panelElementVpadding  // PanelCard spacing: 0; add manually
        visible: !root._recCollapsed
        spacing: Style.panelElementHpadding

        // Col 1 — Mode picker
        // implicitWidth: content-driven, max(labelA, labelB) + hpadding ≤ 250px (~70–80px)
        TogglePair {
            labelA:   "Single"
            labelB:   "Replay"
            selected: root._modeIdx          // 0 = single/oneshot, 1 = replay
            enabled:  !(root.screenrecProcess && root.screenrecProcess.recording)
            onToggled: (idx) => root._modeIdx = idx
        }

        // Col 2 — mode-dependent context (Layout.fillWidth: true — consumes remaining space)
        PanelButton {
            // Single mode: region pick trigger
            // implicitWidth: content-driven; fillWidth expands it
            Layout.fillWidth: true
            visible:  root._modeIdx === 0
            label:    "Region Pick"
            onClicked: _regionProc.running = true
        }
        Text {
            // Replay mode: static hint — plain Text, not ScrollingText
            // (ScrollingText only scrolls when text overflows its width; hint is always short)
            Layout.fillWidth: true
            visible:        root._modeIdx === 1
            text:           "W-S-e: capture replay"
            color:          Style.textMuted
            font.family:    Style.fontMono
            font.pixelSize: Style.fontSizeSubtle
            verticalAlignment: Text.AlignVCenter
        }

        // Col 3 — replay duration picker (Replay mode only)
        // implicitWidth: content-driven, valueText + hpadding ≥ 24px ≤ 300px (~40–50px for "30s")
        // STUB — wire to Prefs.replaySaveDefaultSecs later
        ScrollChip {
            visible: root._modeIdx === 1
            variant: "value"
            text:    "30s"
            onScrolled: (delta) => { /* stub */ }
        }

        // Col 4 — Start / Stop
        // FIFO: writes screenrecToggle. State read from screenrecProcess.recording.
        TogglePair {
            readonly property bool _rec:
                root.screenrecProcess && root.screenrecProcess.recording
            labelA:     "■"
            labelB:     "󰑊"
            fontFamily: Style.fontNerd
            colorA:     _rec ? Style.textSuccess : Style.textMuted
            colorB:     Style.textCritical
            selected:   _rec ? 1 : 0
            onToggled:  (idx) => root._fifo("screenrecToggle")
        }
    }

    // Row 3 — Audio source (SegmentedControl — not yet built; see step 13)
    // SegmentedControl {
    //     Layout.fillWidth: true
    //     visible: !(root._modeIsReplay && root.screenrecProcess && root.screenrecProcess.active)
    //     model:    ["None", "System", "Mic", "Both"]
    //     selected: root._audioIdx
    //     onToggled: (idx) => root._audioIdx = idx
    // }
}
```

**FIFO as single source of truth:**

All ControlPanel write actions go through `_fifo(cmd)` — a helper that spawns `sh -c 'echo CMD > FIFO'`. This is the same mechanism rc.xml uses for W-S-r. Every control path (keybind, panel, toast) therefore goes through the same FIFO → FifoListener → ScreenrecProcess chain. Reading state still comes from `screenrecProcess` and `Prefs` directly.

```qml
// In ControlPanel
function _fifo(cmd) {
    _fifoProc.command = ["sh", "-c", "echo '" + cmd + "' > \"$HOME/.local/share/pillbox/pillbox.fifo\""]
    _fifoProc.running = true
}
Process { id: _fifoProc }
```

**Behavior:**
- **SectionHeader**: tapping collapses/expands Row 2. State in `_recCollapsed: bool`.
- **Mode TogglePair** (`Single | Replay`): writes `screenrecSetMode:oneshot` or `screenrecSetMode:replay` to FIFO. `selected` driven by `Prefs.recMode` (reactive — updates when FifoListener processes the command). Blocked (disabled) while `screenrecProcess.active` — covers both "oneshot recording in progress" and "replay daemon is running".
- **Col 2 — Single mode** (`PanelButton "Region Pick"`): launches `pillbox-screenrec-region` directly (slurp needs pointer grab as labwc child). Disabled while `screenrecProcess.active`.
- **Col 2 — Replay mode** (`Text`): static hint only. No interaction.
- **Col 3 — ScrollChip** (Replay only): shows current replay save duration. Scroll to cycle through `[5, 10, 30, 60, 120, 300]` seconds. Stubbed for now — wire to `Prefs.replaySaveDefaultSecs` in a follow-up pass.
- **Start/Stop TogglePair**: writes `screenrecToggle` to FIFO. `selected` driven by `screenrecProcess.recording`.

`screenrecSetMode` chain: FIFO → `FifoListener.screenrecSetModeRequested(mode)` → `shell.qml` → `screenrec.setMode(mode)` → `Prefs.setRecMode(mode)` + start/stop daemon.

---

### 2I. Prefs Entries

| Key | Default | Notes |
|---|---|---|
| `screenshotDir` | `~/.config/pillbox/media/Screenshots` | Unchanged |
| `recordingDir` | `~/.config/pillbox/media/Recordings` | Both modes |
| `replayDir` | `~/.config/pillbox/media/Replays` | Replay clips |
| `recMode` | `"oneshot"` | Persisted mode preference |
| `replayBufferSecs` | `300` | Rolling buffer size (5 min) |
| `replaySaveDefaultSecs` | `30` | W-S-e save duration in replay mode |
| `recordingFps` | `60` | Shared across modes |
| `recAudio` | `"none"` | Audio mode: `"none"`, `"system"`, `"mic"`, `"both"` |

---

## 3. Replay Buffer

Covered in section 2C. Replay is Mode B of Screenrec — always-on, signal-controlled. Not a standalone module.

---

## 4. Audio Capture

### 4A. gsr Audio Model

gsr accepts zero or more `-a <source>` flags. Each `-a` adds one audio source mixed into the recording:

| Source string | Meaning |
|---|---|
| `default_output` | Desktop / system audio (default output device) |
| `default_input` | Microphone (default input device) |

The flag can be specified multiple times. To capture both: `-a default_output -a default_input`.

**Key constraint: audio flags are baked into the gsr invocation at spawn time.** There is no signal to change audio sources while gsr is running. To switch audio modes the process must be stopped and restarted with new flags.

### 4B. Pillbox Audio Modes

Four modes, mutually exclusive. Selected via SegmentedControl in ControlPanel.

| Pillbox mode | gsr flags |
|---|---|
| None | (no `-a` flag) |
| System | `-a default_output` |
| Mic | `-a default_input` |
| Both | `-a default_output -a default_input` |

The script already maps these correctly in `_audio_flags()`. ScreenrecProcess passes `--audio <mode>` to the script on each invocation.

### 4C. UI Decision — Replay Mode Interaction

Because audio cannot be changed without restarting gsr:

- **Single mode:** audio can be changed freely between recordings. SegmentedControl is always enabled. The selected mode takes effect on the next `toggle()` call (next spawn).
- **Replay mode:** the daemon is already running. Changing audio would require stopping and restarting the daemon — losing the replay buffer. This is destructive and unexpected.

**Decision:** Hide the audio SegmentedControl row entirely while the Replay daemon is active. The row is visible only when:
- Mode is Single, OR
- Mode is Replay but the daemon has not started yet (i.e., `!screenrecProcess.active`)

When hidden in Replay mode, the last-selected audio mode is still stored in Prefs and will apply if/when the daemon is restarted.

### 4D. Prefs Entry

Add `recAudio` (default `"none"`) to Prefs. See section 2I update below.

### 4E. ControlPanel Row 3

Row 3 in the Screenrec PanelCard, below the mode/start row:

```qml
// Row 3 — Audio source
SegmentedControl {
    Layout.fillWidth: true
    visible: !(root._modeIdx === 1 && root.screenrecProcess && root.screenrecProcess.active)
    model:    ["None", "System", "Mic", "Both"]
    selected: root._audioIdx
    onToggled: (idx) => {
        root._audioIdx = idx
        // Prefs.recAudio = ["none","system","mic","both"][idx]  // wire when Prefs entry added
    }
}
```

`_audioIdx` is a ControlPanel local property (int, default 0) until Prefs wiring is done.

---

## Build Todo

- [x] **1. Build new reusable elements** — `ToastWindow.qml`, `ToastController.qml`, `MediaThumbnail.qml`, `ToastTimer.qml`.
- [x] **2. Build the rest of the UI** — `module-toasts/ScreenshotPreview.qml`, `module-toasts/ScreenrecToast.qml`, Screenshots tab in NotificationPanel, Screenrec section in Control panel.
- [x] **3. Update the plan with what has been completed. Commit and push.**
- [x] **4. Rewrite screenrec script backend** — `pillbox-screenrec` (oneshot + replay sub-modes, notify FIFO, signal-based CTL), `pillbox-screenrec-saved` (write to notify FIFO). See section 2E. See D9.
- [x] **5. Rewrite `ScreenrecProcess.qml`** — dual mode, `Component.onCompleted` init for replay, new API (`toggle`, `saveReplay`, `saveReplaySeconds`, `pause`, `emergencyStop`). See section 2F.
- [x] **6. Update `FifoListener.qml` + `shell.qml`** — replace stale screenrec commands with new ones. See section 2F.
- [x] **7. Rewrite ControlPanel screenrec section** — PanelCard + SectionHeader (collapsible) + RowLayout: TogglePair mode (Single|Replay), PanelButton/Text col2 (mode-dependent), ScrollChip duration stub, TogglePair start/stop with state-based color. See section 2H.
- [x] **7a. Build `SegmentedControl.qml`** — equal-width segments via `x`-positioning inside a clipped `Rectangle`. Outer border + radius on container; inner vertical dividers. `fontFamily` prop for Nerd Font glyphs.
- [x] **8. Add missing Prefs entries** — `replayBufferSecs` (default 300), `replaySaveDefaultSecs` (default 30), `recordingFps` (default 60). ScreenrecProcess wired to pass `--fps` and `--replay-secs` from Prefs. ScrollChip in ControlPanel wired to `Prefs.replaySaveDefaultSecs`, cycles `[10,30,60,300,600,1800]` s, calls `Prefs.setReplaySaveDefaultSecs`. See section 2I.
- [x] **9. Build screenshot image bank** — `_scanProc` added to `ScreenshotProcess.qml` (find + StdioCollector, mtime sort + cap 200). Scan fires in `Component.onCompleted`. Screenshots tab in NotificationPanel renders correctly. Delete button added to each card (calls `screenshotProcess.deleteScreenshot(path)` — immediate list update + async `rm -f`). See D8 for implementation deviations.
- [ ] **10. Build post-recording and post-screenshot UI** — `ScreenrecToast.qml` (wire to new signal protocol), `ScreenshotPreview.qml` (review and fix). Toast architecture spec remains valid (section 1B, 2G).
- [ ] **11. Fix toast** — both `ScreenshotPreview.qml` and `ScreenrecToast.qml` need review and repair to work with current state.
- [x] **12. W-S-e mode-aware keybind** — `pillbox-screenrec-e` reads `recMode` + `replaySaveDefaultSecs` from `pillbox.conf`. Single: slurp → `screenrecStartRegionWith`. Replay: `screenrecSaveReplay:N`. rc.xml updated; symlinked to `~/.local/bin`. See 2D.
- [x] **14. Wire ControlPanel TogglePairs through FIFO** — Mode TogglePair: writes `screenrecSetMode:oneshot|replay`, `selected` from `Prefs.recMode`, `enabled` from `!screenrecProcess.recording` (not `active` — allows switching back from Replay while daemon is idle). Start/Stop: writes `screenrecToggle`. `_fifo(cmd)` helper + `_fifoProc` Process added. `screenrecSetMode` wired in FifoListener, shell.qml; `setMode(mode)` added to ScreenrecProcess — stops daemon automatically when switching replay→oneshot while idle.
- [x] **13. Wire audio SegmentedControl in ControlPanel** — `recAudio` Prefs entry added (default `"none"`). SegmentedControl Row 2 added inside screenrec PanelCard below the controls row; hidden when replay daemon is `active` (can't change audio mid-daemon without losing buffer). ScreenrecProcess passes `--audio` from Prefs on every spawn. See section 4. — uncomment Row 3; add `_audioIdx` property; hide row when Replay daemon is active (`_modeIdx === 1 && screenrecProcess.active`); add `recAudio` Prefs entry (default `"none"`); wire ScreenrecProcess to pass `--audio <mode>` to script on each invocation. See section 4.

> **Deviation policy:** if the build deviates from any spec above, note the deviation and the new decision inline (do not delete the original spec). User will review later to revert, fix, or accept.

---

## Build Notes & Deviations

### D1 — ToastController not separately instantiated in shell.qml

**Plan:** ToastController is a standalone QtObject instantiated in shell.qml, receiving references to toast modules from ToastWindow.

**Deviation:** ToastController exists as a standalone file (`module-reusable-elements/ToastController.qml`) but is **not** instantiated anywhere. Instead, `ToastWindow.visible` is computed directly from the Loader items' `shouldShow` properties:
```qml
visible: (_ssLoader.item ? _ssLoader.item.shouldShow : false) ||
         (_srLoader.item  ? _srLoader.item.shouldShow  : false)
```
**Reason:** The circular reference problem — ToastWindow needs ToastController's shouldShow to set visible, and ToastController needs refs to modules inside ToastWindow. Inline computation avoids the dependency chain without losing any functionality. ToastController.qml remains as a reference/documentation artifact.

### D2 — Toast modules loaded via Qt.resolvedUrl Loader

**Plan:** Toast modules are children of ToastWindow's ColumnLayout.

**Deviation:** Uses `Loader { source: Qt.resolvedUrl("../module-toasts/...") }` inside ToastWindow, same pattern as PanelSurface loading module-panels. This avoids a circular import between module-reusable-elements (ToastWindow) and module-toasts (ScreenshotPreview, ScreenrecToast).

### D3 — No entrance/exit animations in first build

**Plan:** Entrance animation — slide in from right, `NumberAnimation` on x, `Easing.OutCubic`, 150–250ms.

**Deviation:** Deferred. First build uses `visible: shouldShow` with no animation. Reason: functional correctness first. Animations to be added as a follow-up.

### D4 — Panel does not auto-dismiss when starting recording

**Plan (section 2F):** "For Screen / Window: fires the appropriate FIFO command, panel dismisses"

**Deviation:** The ControlPanel Start button calls `screenrecProcess.startScreen()` directly without dismissing the panel. The user can press ESC or click outside. Reason: no `dismissRequested` signal on ControlPanel. This is consistent with how other panels behave (they don't self-dismiss on button actions). To fix properly, a `dismissRequested` signal + PanelSurface wiring would be needed.

### D5 — screenshotUI FIFO auto-switch to Screenshots tab ✓ FIXED

**Plan:** `screenshotUI` FIFO command → opens NotificationPanel pre-landed on Screenshots tab.

**Original deviation:** Defaulted to tab 0. Loader-based panels don't persist state between open/close.

**Fix implemented:** `PanelSurface` gained `property int notificationInitialTab: 0`. In `shell.qml`, `onScreenshotUIRequested` sets `panelSurface.notificationInitialTab = 1` then calls `panelController.toggle("notifications")`. In PanelSurface's notifications `onLoaded`, `item._tab = root.notificationInitialTab` is set and then `root.notificationInitialTab = 0` resets it so normal W-6 always opens on tab 0. PanelSurface was given `id: panelSurface` in shell.qml.

### D6 — Notification card urgency color uses mat3Error directly

**Plan:** No spec change — the original code used `Style.color11`.

**Deviation:** `Style.color11` doesn't exist in the Style singleton. Changed to `Style.mat3Error` (the MD3 error color) inline in the card color expression. The result is equivalent to the original intent.

### D8 — Image bank scan: `find -L` + `sh -c` required (symlink + escape issues)

**Plan (1B):** `find "$dir" -maxdepth 1 -type f -name "*.png" -printf "%T@\t%p\n"` as direct Process command array.

**Deviations:**
1. `find` without `-L` does not traverse a symlink given as the starting path. `~/.config/pillbox/media/Screenshots` is a symlink → `~/Screenshots`; scan returned 0 files. Fix: `find -L`.
2. `"\t"` and `"\n"` in a QML JS string literal are tab and newline characters (ASCII 9/10). Passing them as a `find -printf` format argument produces literal chars in the output rather than format sequences. Fix: wrap in `sh -c` with single-quoted format string so `find` receives `\t`/`\n` escape sequences it interprets itself.
3. Path passed via positional arg `"$1"` (not string interpolation) for correct quoting.
4. **Addition not in plan:** Delete button added to each screenshot card (`variant: "critical"`). Calls `screenshotProcess.deleteScreenshot(path)` — immediately filters the entry from the in-memory list, then runs `rm -f` async via `_deleteProc` in `ScreenshotProcess.qml`.

**Final command:**
```qml
command: ["sh", "-c",
    "find -L \"$1\" -maxdepth 1 -type f -name '*.png' -printf '%T@\\t%p\\n' 2>/dev/null",
    "sh", root._dir]
```

### D9 — Script backend: notify FIFO, gsr stdout suppression, audio flag added early

**Plan (2E):** Notify mechanism described as forwarding `-sc` callbacks to stdout. Plan said "notify FIFO (`screenrec-notify`)" for inter-process comms.

**Implementation details:**
1. **Notify FIFO reader pattern:** `exec 4<>"$NOTIFY_FIFO"` holds write end open (prevents blocking on callback open). Background subshell closes its inherited fd 4, then reads from the FIFO via redirected stdin (`done < "$NOTIFY_FIFO"`). Parent closes fd 4 in `cleanup()` → subshell gets EOF → drains remaining messages → exits. `wait "$NOTIFY_READER_PID"` in cleanup ensures all messages are emitted before the script exits.
2. **gsr stdout suppressed:** gsr v5 prints saved paths to stdout in addition to calling -sc. Added `>/dev/null` to both gsr invocations to prevent leaking raw paths into the protocol stream.
3. **SIGRTMIN computed at runtime:** `python3 -c 'import signal; print(int(signal.SIGRTMIN))'` with fallback 34. Signal arithmetic uses `$(( _RTMIN + N ))`.
4. **`saveReplay:10` added:** man page shows `SIGRTMIN+1` = save last 10 seconds, not in original plan. Added for completeness.
5. **Audio (`--audio`) added ahead of ControlPanel work:** Plan said script should accept audio param without breaking when absent. Added `--audio none|system|mic|both|<raw-gsr-source>` to both oneshot and replay invocations. Maps to zero, one, or two `-a` gsr flags. Passes through unchanged when `--audio none` or omitted. ControlPanel (step 7) and ScreenrecProcess (step 5) can wire it without revisiting the script.

### D7 — NotificationPanel missing Quickshell.Io import + keyboard Tab shortcut added

**Fix:** `NotificationPanel.qml` was missing `import Quickshell.Io` — caused `Process is not a type` error on open, making the panel invisible. Added the import.

**Addition:** `focus: true` added to NotificationPanel root Item (mirrors MediaPlayerPanel pattern). `Keys.onPressed` handles `Qt.Key_Tab` to toggle `_tab` between 0 (Notifications) and 1 (Screenshots). PanelSurface Loader already has `focus: true` so keyboard focus propagates automatically on panel open.
