# Completed Work Log

Reverse-chronological. Each entry describes what was built and key decisions made, for future reference and audit.

---

## MediaPlayerPanel — Keyboard Navigation

Panel-specific keybinds for MPRIS playback control without leaving the keyboard.

- [x] `MediaPlayerPanel.qml` — added `focus: true` on root `Item` so it holds active focus when loaded (receives key events before the `PanelSurface` Loader)
- [x] `Keys.onPressed` handler: P = play/pause, N = next, B = back, M = focus player window, Up/Down = volume ±5%
- [x] All handled keys set `event.accepted = true` — consumed before PanelSurface's panel-navigation handlers
- [x] Unknown keys and no-player state set `event.accepted = false` — fall through to Loader (ESC dismisses, Left/Right navigate panels)

**Key decisions:**
- Keys chosen to avoid conflict with PanelSurface's Left/Right (panel navigation) and Escape (dismiss)
- `focus: true` on the panel root is the correct QML mechanism: key events travel upward from the active-focus item; panel handles what it knows, Loader handles the rest
- M uses `ToplevelProcess.activate()` (same as `_focusPlayer()` does for the album art click) — no separate keybind logic needed

---

## Visual Layer — Pill Polish + Notification Priority

All pills receive visual treatment. Notification pill gets two-tier urgency.

### Pill borders
- [x] `PillWindow`: `border.color: Style.borderFaintColor` + `border.width: Style.pillBorderWidth`
- [x] `Prefs`: `pillBorderWidth` (default 1, setter `setPillBorderWidth`) + `borderColorMode` ("subtle" / "vibrant", setter `setBorderColorMode`)
- [x] `Style`: `pillBorderWidth` Prefs-derived; `borderFaintColor` mode-driven (subtle = `mat3OutlineVariant`, vibrant = `mat3Outline`)
- [x] `SettingsPanel` Borders card: added Pill row (Off/Thin/Thick) and Color mode row (Subtle/Vibrant); Reset button calls `setPillBorderWidth(1)` + `setBorderColorMode("subtle")` + `clearMat3Overrides()`

### Pill top margin
- [x] `PillWindow`: `margins.top: Screen.height * 0.01` → `0.02` (~22px at 1080p, ~29px at 1440p)

### Vertical text centering
- [x] All five pills: replaced `anchors.verticalCenter: parent.verticalCenter` on Row/Text elements with `height: parent.height` + `verticalAlignment: Text.AlignVCenter`. Root cause: JetBrainsMono Nerd Font inflates the line-height bounding box for icon glyphs, causing `verticalCenter` to position above visual center.

### TimePill urgent states (both built)
- [x] Calendar-imminent mode (`_calendarImminent && !_timerActive`): `bgColor = accentBgColor`; scrolling marquee text `"${summary} in ${N}m"`, 200 px cap, 1.5 s pause at each end, 20 ms/px; `onTextChanged` resets scroll so minute-by-minute updates restart cleanly
- [x] Urgent countdown (`_urgentCountdown`: timer mode, active, `_remainMs < 10 000`): `bgColor = criticalBgColor`; text color `textCritical`; appends `displayCenti` to show centiseconds
- [x] `_calendarText` computed property derives `"${nextEvent.summary} in ${minutes}m"` from `calendarProcess.nextEvent`

### Pill glyph + text polish
- [x] `WorkspacePill`: active workspace dot → `accentColor`; inactive dots → `textMuted`
- [x] `MprisPill`: playback glyph → `accentColor` (static); text → `"Artist — Title"` with fallback chain (artist+title → title → artist); text scrolls in clipped container (same 200 px / 1.5 s / 20 ms/px pattern as TimePill); glyph stays static while text scrolls
- [x] `WindowPill`: app glyph → `accentColor`

### NotificationPill — two-tier priority
- [x] **Normal** peek: priority 6, 7 s — beats MprisPill (5); yields to WorkspacePill (100) and WindowPill (200)
- [x] **Critical** peek: priority 1000, 10 s — beats every other pill including WindowPill
- [x] `bgColor`: `criticalBgColor` when any critical notification tracked; `pillBgColor` otherwise
- [x] Text color: `textCritical` when critical; `textPrimary` otherwise
- [x] Display format: `"N !C"` (was `"N | C"`) to make the critical count visually distinct
- [x] Two independent timers (`_peekTimer` 7 000 ms, `_criticalPeekTimer` 10 000 ms)

### CalendarPanel — refresh button
- [x] Nerd Font refresh glyph (nf-fa-refresh, ``), bottom-right of month grid, `textMuted` → `textNormal` on hover, tooltip "Refresh", 300 ms delay
- [x] On click: `calendarProcess.refresh()` + `tasksProcess.refresh()`

### Mako — D-Bus activation blocked
- [x] mako was not in `labwc/autostart` but ships `/usr/share/dbus-1/services/fr.emersion.mako.service`, which auto-launched it on the first notification and stole `org.freedesktop.Notifications` before Quickshell could claim it
- [x] Fix: `systemctl --user mask mako` → symlinks `mako.service → /dev/null`, permanently blocking D-Bus activation without uninstalling the package

**Key decisions:**
- Normal notification priority 6 (not 10+): should break through MPRIS but not override workspace/window-switcher — those are immediate UI context cues
- Critical priority 1000: no other pill should ever suppress a critical notification
- `borderFaintColor` mode-driven rather than adding a second border token — keeps the token count low while giving the user the control they need
- Scroll speed 20 ms/px (same for both MprisPill and TimePill) for consistency; `onTextChanged` resets position so content changes don't mid-scroll

---

## Material Design 3 Color Pipeline

Full mat3 pipeline from matugen → Prefs → Style → components. Replaces Nord-specific heuristics with wallpaper-driven semantic colors.

### WallpaperProcess
- [x] After base16 extraction, added mat3 block parsing `data.colors.<role>.dark.color` for 12 roles
- [x] Roles → Prefs setters: `primary`, `primary_container`, `background`, `on_background`, `surface_container_low`, `surface_container_high`, `on_surface`, `on_surface_variant`, `outline`, `outline_variant`, `error`, `error_container`

### Prefs.qml
- [x] 12 `mat3*Override` string properties (all default `""`) + readonly aliases + setters
- [x] `clearMat3Overrides()` — resets all 12; called by Reset button and extractColors toggle-off

### Style.qml
- [x] New Section 1.5 — Mat3 Roles: 12 `readonly property color mat3*` with override-or-fallback pattern
- [x] Fixed section redesigned (Option B): mat3 roles define the semantics
  - `pillBgColor` / `panelBgColor` ← `mat3Background`
  - `surfaceLowColor` ← `mat3SurfaceContainerLow`, `surfaceMidColor` ← `mat3SurfaceContainerHigh`
  - `borderFaintColor` ← mode-driven (`mat3OutlineVariant` subtle / `mat3Outline` vibrant)
  - `borderSoftColor` ← `mat3Outline`
  - `accentColor` ← `mat3Primary`, `accentBgColor` ← `mat3PrimaryContainer`
  - `criticalBgColor` ← `mat3ErrorContainer`
  - `textPrimary` ← `mat3OnBackground`, `textNormal` ← `mat3OnSurface`
  - `textSecondary` ← `mat3OnSurfaceVariant`, `textMuted` ← `mat3Outline` (**fix resolved**: now genuinely dimmer than secondary)
  - `textFaint` ← `mat3OutlineVariant`, `textAccent` ← `mat3Primary`, `textCritical` ← `mat3Error`
- [x] Removed: `borderAccentColor` (redundant with `accentColor`), `textWeekend` (CalendarPanel uses `accentColor` inline), `dotIndicator` (CalendarPanel uses `accentColor` inline)

### Component touch-ups
- [x] `CalendarPanel`: `textWeekend` → `accentColor` (weekend headers); `borderAccentColor` → `accentColor` (today cell, event dots, back links); today cell text → `panelBgColor` (contrast fix: mat3 primary is light in dark mode — light text on light accent bg was unreadable)
- [x] `TimerWidget`: 3× `borderAccentColor` → `accentColor`

**Key decisions:**
- Option B mapping: mat3 roles define the intent, not the other way around. We ask "what does mat3 say this surface/text/border should be?" — not "which colorN is closest to my existing token?". This required redesigning the Fixed section vocabulary.
- `textSuccess` stays on `color14` (Aurora green) — mat3 has no success/positive role
- `accentBgHover` derived as `Qt.lighter(mat3PrimaryContainer, 1.3)` — no mat3 hover role exists; this produces a consistent brightness step regardless of palette
- Verified: `data.colors.<role>.dark.color` path in matugen v4.1.0 JSON (not `data.base16`)

---

## Control Panel (W-7) — post-ship fixes

- [x] Session buttons: text labels → Nerd Font glyphs (`󰒓` `󰍃` `󰜉` `󰐥`), tooltips via `QQC.ToolTip` on hover (500ms delay). `PanelButton` now has `tooltip` property + import.
- [x] `WheelHandler` → `MouseArea.onWheel`: WheelHandler silently didn't fire inside the inline component on this setup; `MouseArea` with `onWheel` is the established working pattern (matches MediaPlayerPanel).
- [x] `AudioProcess` rewritten from PipeWire-native to subprocess: `PwNodeAudio.volume` reads and writes as 0 via QML even though the C++ object is valid — likely not exposed as a writable Q_PROPERTY in this Quickshell build. Volume and mute now go through `wpctl get-volume` / `wpctl set-volume` / `wpctl set-mute` (same as labwc keybinds). Device names still read from `Pipewire.defaultAudioSink/Source.nickname` (string properties work fine).
- [x] `VolumeButton` interface changed from `required property var node` (PwNode) to `property real volume`, `property bool muted`, `property string name` + signals `muteToggled()` / `scrolled(real delta)` / `rightClicked()`. ControlPanel wires signals to AudioProcess methods.
- [x] Exit button stubbed (`console.log` only) during testing — to be re-wired when ready.

---

## Control Panel (W-7)

### Audio (AudioProcess.qml + ControlPanel.qml)
- [x] `AudioProcess` — polls `wpctl get-volume @DEFAULT_AUDIO_SINK/SOURCE@` every 3s; runs `wpctl set-volume` / `wpctl set-mute` for changes; re-polls after each command. Device names from `Pipewire.defaultAudioSink/Source` (string props work).
- [x] Inline `VolumeButton` component (uppercase required for QML inline components): left-click mutes/unmutes, scroll ±5% volume, right-click opens `pavucontrol-qt`
- [x] Label priority: **MUTED** (when muted) → volume% (for 1.5s after any scroll) → device name (nickname > description > name)
- [x] Muted state: button border highlights with `accentColor`, text color switches to `textMuted`
- [x] Two VolumeButton rows: source (mic) on top, sink (speaker) below

### Network (NetworkProcess.qml + ControlPanel.qml)
- [x] `NetworkProcess` — polls `ip -4 route get 1.1.1.1` every 30s; `connected: bool`, `localIp: string`
- [x] IP display: left-click toggles `nmcli networking on/off`, right-click opens `nm-connection-editor`
- [x] Connected → shows local IP in `textSuccess`; disconnected → "No connection" in `textCritical`

### Session row
- [x] Four buttons right-aligned: **Reconfigure** (labwc `--reconfigure`), **Exit**, **Reboot**, **Shutdown**
- [x] Destructive actions (Exit / Reboot / Shutdown) trigger a 3-second countdown in-place
- [x] Countdown uses `Date.now()` delta + 100ms Timer — same drift-free pattern as TimerProcess
- [x] Cancel button dismisses countdown with no action
- [x] Full sentences: "Exiting in Xs...", "Rebooting in Xs...", "Shutting down in Xs..."

### System graphs placeholder
- [x] 120px reserved rectangle with "System" faint label — visual slot for future CPU/RAM/net graphs

### Wiring
- [x] `AudioProcess` + `NetworkProcess` instantiated in `shell.qml`, injected into `PanelSurface`
- [x] `FifoListener` dispatches `toggleControl` → `panelController.toggle("control")`
- [x] `PanelController.panelOrder` includes "control" (left-right nav position: between calendar and mediaPlayer)
- [x] `PanelSurface` sources `ControlPanel.qml` and injects `audioProcess` + `networkProcess` on load
- [x] W-7 keybind added to `labwc/rc.xml`

---

## Wallpaper — Video Rendering, Thumbnails & Panel Improvements

### Video rendering (shell.qml)
- [x] `import QtMultimedia` added
- [x] `MediaPlayer` + `AudioOutput { volume: 0 }` + `VideoOutput` added to `wallpaperWindow`
- [x] `_vidPlayer.source` binds to `wallpaper.currentPath` when `sourceType === "video"`; `onSourceChanged: if (source !== "") play()` auto-starts playback
- [x] `loops: MediaPlayer.Infinite` — seamless looping, muted audio
- [x] Backend: `qt6-multimedia-ffmpeg` (FFmpeg direct — `gst-plugins-good` not installed, GStreamer path skipped)

### Video thumbnails (WallpaperProcess.qml)
- [x] `_mkdirProc` — `mkdir -p ~/.cache/pillbox/thumbs` on startup
- [x] `_thumbProc` — sequential ffmpeg queue: `-ss 00:00:01 -i <path> -frames:v 1 -q:v 3 <cache>.jpg`. Input seek (`-ss` before `-i`) seeks in the container before decoding — fast on large files
- [x] `thumbsReady` — JS object reassigned on each completion for QML reactivity (`path → true`). Only new paths (not already in `thumbsReady`) get queued for ffmpeg
- [x] `thumbPath(videoPath)` — public function returning cache JPEG path; used by both `WallpaperProcess` and `WallpaperPanel`
- [x] Queue starts after `_scanVidProc` finishes
- [x] `_pendingVideoExtract` — if user picks a video before its thumb is ready, matugen fires automatically when that thumb completes
- [x] `setVideo()` now triggers color extraction via thumbnail JPEG (was a placeholder)

### Panel improvements (WallpaperPanel.qml + PanelSurface.qml)
- [x] Video tile: `Image` shows ffmpeg thumbnail when `thumbsReady[path]`; play icon placeholder until then. `clip: true` + `layer.enabled: true` for radius clipping — matches image tile pattern
- [x] `_hasThumb` property on tile delegate drives thumbnail/placeholder toggle reactively
- [x] Video section renamed "VIDEO / GIF" → "Videos" (GIFs stay in Images — rendered by `AnimatedImage`)
- [x] Empty state: "No videos or GIFs found" → "No videos found"
- [x] Scan on panel open: `PanelSurface.onLoaded` triggers `scanDirectory` each time the wallpaper panel loads — picks up files added or removed since last scan
- [x] No-flash rescan: `scanDirectory` only clears file lists when the directory actually changes; same-directory rescans update lists in-place when results arrive
- [x] GIF size cap: `_scanImgProc` excludes GIFs over 50 MB via `-not ( -iname "*.gif" -size +50M )` — `AnimatedImage` decodes on CPU; large GIFs are expensive

**Key decisions:**
- `qt6-multimedia-ffmpeg` used over GStreamer — `gst-plugins-good` absent; FFmpeg path works cleanly on this system
- `AudioOutput { volume: 0 }` is required — Qt logs a warning without it; volume 0 keeps wallpaper silent
- `thumbsReady` is in-memory per Quickshell session; thumbnail JPEGs persist on disk across restarts, but the map rebuilds from disk via scan on startup/panel-open
- GIF 50 MB cap chosen as practical ceiling — GIFs above this are rare for wallpaper use; users making large animated wallpapers use WebP or MP4

---

## Wallpaper Service — Qt-Native Rewrite

Full rewrite of the wallpaper stack, replacing the yin daemon with direct Qt rendering. Settings persistence fixed as a prerequisite.

### Why yin was dropped
- `yinctl` called from Quickshell's `Process` exited with code 6 (IPC failure). Wrapper script `helper/yin_set.sh` → `~/.local/bin/yin-set` was built as a workaround — but yin also failed on video (suspected GPU driver / package regression). External daemons abandoned entirely.

### WallpaperWindow (shell.qml)
- [x] Replaced `colorBg` PanelWindow (`WlrLayer.Bottom`) with `wallpaperWindow` at `WlrLayer.Background` — correct layer, no more z-fighting
- [x] `Rectangle` child handles solid color; `AnimatedImage` child handles static images (`PreserveAspectCrop`, `cache: false`)
- [x] `AnimatedImage` handles both static JPG/PNG/WebP/AVIF and animated GIF with a single element — no branching needed
- [x] On startup: `AnimatedImage.source` binds to `Prefs.wallpaperPath` → wallpaper auto-restores, no explicit restore call
- [x] **Video:** `MediaPlayer` + `VideoOutput` added — see "Video Rendering" entry above

### WallpaperProcess (root-processes/WallpaperProcess.qml)
- [x] Removed `yinProc`, `_pendingYinPath`, `_applyYin()` entirely
- [x] Replaced single `scanProc` with two separate processes:
  - `_scanImgProc` — `find <dir> -maxdepth 1 -type f`, filtered by image extensions (`.jpg .jpeg .png .webp .avif .gif`), no size cap
  - `_scanVidProc` — same with `-size -100M` flag, filtered by video extensions (`.mp4 .webm .mkv .mov`), 100 MB cap per file
- [x] Both lists capped at 200 items to keep the Repeater fast
- [x] `setVideo()` persists path/sourceType; rendering and color extraction now fully implemented (see above)
- [x] `_maybeExtract()` (matugen) — triggered by `setImage()` and `setVideo()` (via thumbnail); not triggered on slideshow advances

### matugen color extraction
- [x] `matugenProc` in WallpaperProcess fires when `Prefs.extractColors` is true and user picks an image
- [x] Parses `base16` JSON section (`base00`–`base0f` → `color0Override`–`color15Override` in Prefs)
- [x] `Style.qml` variable section reads Prefs overrides with Nord fallback: `Prefs.color0Override !== "" ? Prefs.color0Override : "#2E3440"`
- [x] Toggle in Settings → Appearance. Turning off clears all overrides, restoring Nord.

### WallpaperPanel (module-panels/WallpaperPanel.qml)
- [x] Fixed critical layout bug: grid container `Item` used `height:` inside `ColumnLayout` — ColumnLayout reads `implicitHeight` (0 for plain Item), starving the grid of vertical space. Fixed with `implicitHeight:` on both grid containers.
- [x] Switched both grids from `rows: 3, flow: TopToBottom, HorizontalFlick` to `columns: 3, flow: LeftToRight, VerticalFlick` — more natural UX, scrolls when > 9 items
- [x] `.gif` files moved to image extensions list (handled by `AnimatedImage`, not video pipeline)

### Infrastructure cleanup
- [x] Removed `yin &` from `labwc/autostart`
- [x] Removed `yin-set` symlink from `install.sh`
- [x] `helper/yin_set.sh` retained as dead file (no references; low-priority cleanup)

**Scope decisions (documented in wallpaper-service-planning.md, now archived):**
- Global wallpaper only (no per-workspace) — additive later if needed
- Video file size cap: 100 MB (LOTR trilogy = 25 GB; wallpaper loops < 50 MB)
- Grid item cap: 200 per section
- Theming kept in WallpaperProcess (trigger is wallpaper change event)

**Remaining fix candidates:**
- GIF wallpapers: should work via `AnimatedImage` — needs end-to-end test with an actual animated GIF file
- Active wallpaper goes blank if file is deleted from disk — no fallback to color mode
- Visual layer makeover: replace Fixed section (hardcoded Nord semantic tokens) with a proper dynamic color system. Candidate: Material You / mat3 mapped onto the 16-slot base16 palette.
- Multi-monitor: `wallpaperWindow` currently targets `Quickshell.screens[0]` only

---

## Settings Persistence Fix

- [x] `Prefs.qml` and `SettingsProcess.qml` both use `QtCore.Settings { location: ... }` to write to `~/.config/pillbox.conf`.

**Root cause of the bug:** `StandardPaths.writableLocation()` in QML returns a `file://` URL string (e.g. `file:///home/rauf/.config`), not a plain filesystem path. The original code prepended `"file://"` on top of it, producing `file://file:///home/rauf/.config/pillbox.conf` — an invalid URL. QSettings silently rejected it and fell back to the default mechanism, which requires `organizationName` + `organizationDomain` (not set by Quickshell), so it failed with status 1 and wrote nothing to disk.

**Fix:** Remove the `"file://"` prefix — use `location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/pillbox.conf"` directly. The URL returned by `StandardPaths` is already a valid `file://` URL; appending the filename suffix is sufficient.

**Other dead ends investigated:**
- Subdirectory `~/.config/pillbox/pillbox.conf` — QSettings does not `mkdir -p`; directory didn't exist so writes were silently dropped.
- `Qt.resolvedUrl("../pillbox.conf")` — Quickshell's URL interceptor resolved this to `qs:@/pillbox.conf` and blackholed it.
- `PersistentProperties` (Quickshell built-in) — only survives hot-reloads within a session, not full restarts.
- `QuickshellSettings` — not a user-settings type; it configures the shell's working directory and file-watch behaviour.

---

## Window Switcher — Desktop App List + Scroll

Extended the window switcher (W-Tab) with:

- [x] **Flickable scroll** — `Column` wrapped in `Flickable { contentHeight: col.implicitHeight }`. `implicitHeight` still drives PanelSurface clamping; Flickable scrolls when open windows exceed the capped panel height.
- [x] **Desktop app section** — `filteredApps` computed from `DesktopEntries.applications` (Quickshell singleton, `import Quickshell`). Filters on `entry.name`, skips `noDisplay: true`. Shown only when `filterInput.text !== ""`.
- [x] **Separator** — 1px `panelDividerColor` Rectangle; `visible: filteredApps.length > 0`.
- [x] **App rows** — app name only (no icon). Keyboard selection extends `selectedFlat` into the app list (offset by `filteredWindows.length`). Click or Enter → `entry.execute()` + `dismissed()`.

**API notes:**
- `DesktopEntries.applications` is iterable as a plain list; `.values` pattern is not needed here.
- `DesktopEntry.icon` is a bare XDG name string. `IconImage` resolves theme icons but logs "Cannot open" for icons absent from the theme. Omitted — plain text rows are cleaner.
- `import Quickshell` must be added per-file (not inherited from shell.qml).

---

## Systray Footer in Notification Panel

Right-aligned row of tray icons pinned to the bottom of the W-6 panel.

- [x] `SysTrayBar.qml` — `RowLayout` of 24×24 `IconImage` delegates from `SystemTray.items`. Left-click → `activate()`, right-click → `secondaryActivate()`. Hover state + `ToolTip` using `modelData.title`.
- [x] `NotificationPanel.qml` — 1px `panelBorderColor` divider above the bar; Flickable's `bottom` anchor moved to `_sysDivider.top`. Both divider and bar use `height: 0` when `_rep.count = 0` so layout is identical to before when no tray apps are running. `implicitHeight` adds `(1 + 24 + panelMargin)` when count > 0.

**API quirks discovered:**
- `SystemTray` is a QML singleton namespace from `Quickshell.Services.SystemTray` — instantiating it (`SystemTray { id: x }`) fails with "Element is not creatable."
- `SystemTray.items.count` returns `undefined` (the `ObjectModel` type does not expose `.count` in QML). Use `Repeater.count` to track model size reactively.
- `IconImage` from `Quickshell.Widgets` (not plain `Image`) resolves XDG theme icon names correctly.

---

## Notification System — W-6

D-Bus notification daemon + pill + scrollable panel. Replaces mako entirely.

**Data layer — `NotificationServer.qml`:**
- [x] `NotificationServer` from `Quickshell.Services.Notifications` claims `org.freedesktop.Notifications` on startup. `keepOnReload: false`, `bodySupported / actionsSupported / imageSupported: true`.
- [x] `onNotification`: sets `notif.tracked = true`, captures timestamp into `_timestamps[notif.id]`, increments `_tsVersion` (reactive dependency for `getTimestamp()`), emits `newNotification(notif)`, calls `_recalc()`.
- [x] `_recalc()`: iterates `trackedNotifications.values`, updates `countTotal` and `countCritical`. Triggered by `Connections { onTrackedNotificationsChanged }` and each `onNotification`.
- [x] `clearAll()`: calls `dismiss()` on each tracked notification, deferred recalc via `Qt.callLater`.
- [x] `getTimestamp(id)`: reads `_timestamps[id]`, depends on `_tsVersion` for reactive re-evaluation.

**Pill — `NotificationPill.qml`:**
- [x] Priority 2 during 7 s peek window after any arrival (beats TimePill at 1). Priority 0 otherwise.
- [x] `shouldReveal` follows `_peeking` only — no persistent critical behaviour (removed: caused stale-count ghost pill after `clearAll()` because the priority binding evaluated before the model fully updated).
- [x] Display: `"N | C"` when critical > 0, `"N"` otherwise. Hidden when `countTotal = 0`.
- [x] Background: `Qt.darker(color11, 1.5)` when critical present and pill visible. (`criticalBgColor` at darker 2.4 is indistinguishable from `pillBgColor` at pill scale — pill uses inline override.)
- [x] `PillWindow` updated to read `activePill.bgColor` if present; falls back to `Style.pillBgColor`.

**Panel — `NotificationPanel.qml`:**
- [x] Layout: fixed `_topFixed` ColumnLayout (NavBar + Clear all) + `Flickable` fills remaining height. `implicitHeight` drives PanelSurface clamping; Flickable scrolls when cards exceed available space.
- [x] `Repeater` on `notificationServer.notifications` (`trackedNotifications` model).
- [x] Card: urgency-tinted background (low = `surfaceLowColor`, normal = `surfaceMidColor`, critical = `color11` at 15% opacity). Right-click dismiss via `TapHandler { acceptedButtons: Qt.RightButton }`. `[×]` button top-right as redundant dismiss.
- [x] Two-column layout: left = square image thumbnail (hidden when `notification.image` is empty); right = header (appName + timestamp + `[×]`) + summary + body + action rows.
- [x] Action rows: up to 2 labeled `PanelButton`s + `[⋮]` toggle if more exist. Overflow row (actions 3–4) hidden until `[⋮]` tapped. `identifier === "default"` filtered from labeled actions. `ToolTip` on truncated labels.
- [x] Left-click card-level default action deferred: Qt 6 TapHandler propagation fires both parent and child handlers simultaneously — clicking `[⋮]` also dismisses the card. Right-click + `[×]` are the primary dismiss paths.

**Key decisions:**
- No persistent critical pill: the "stays visible until cleared" behaviour caused a ghost pill after `clearAll()`. Pure 7 s peek for all urgencies is simpler and avoids the race.
- `criticalBgColor` token (`Qt.darker(2.4)`) is correct for panel card tinting but too dark for the pill surface. Pill uses `Qt.darker(1.5)` inline; Style token unchanged.
- Timestamp captured on `onNotification` because `Notification` has no arrival-time property.
- `notify-send` action format: `--action="ID=Label"` (equals separator). Colon separator sends numeric index as ID with full `"key:value"` string as label text.

**Wiring:**
- [x] `root-processes/qmldir`, `module-pills/qmldir`, `module-panels/qmldir` — all three registered.
- [x] `FifoListener` — `toggleNotificationsRequested` + `"toggleNotifications"` dispatch.
- [x] `PanelController.panelOrder` — `["calendar", "mediaPlayer", "notifications", "settings", "wallpaper"]`.
- [x] `PanelSurface` — `notificationServer` property; `"notifications"` Loader case.
- [x] `shell.qml` — `NotificationServer { id: notifServer }`, `NotificationPill`, wired to FifoListener and PanelSurface.
- [x] labwc `rc.xml` — **W-6** → `toggleNotifications`.
- [x] mako killed and removed from autostart.

---

## Media Player Panel — W-3

MPRIS panel with album art, scrolling track info, playback controls, and volume toggle.

**Panel UI — `MediaPlayerPanel.qml`:**
- [x] No-player state: centred `"No active player"` in `textMuted`.
- [x] Album art: square `Item` (`implicitHeight: width`, `Layout.fillWidth`), `Image` with `PreserveAspectCrop` + `clip`, placeholder music glyph (`0xf001`) in `textFaint` over `surfaceLowColor` when `trackArtUrl` empty or load fails. Click → `wlrctl toplevel focus app_id:<desktopEntry>` via short-lived `Process`.
- [x] Controls row: prev `IconButton` (`0xf048`), marquee clip `Item` (scrolling `Text` + `MouseArea` for play/pause), next `IconButton` (`0xf051`). All three respect `canGoPrevious`, `canTogglePlaying`, `canGoNext` guards — dimmed + disabled when unavailable.
- [x] Marquee: `SequentialAnimation` — 1.5 s pause → scroll left to `-(implicitWidth - clipWidth)` at 15ms/px → 1.5 s pause → snap back 400 ms. Resets on `onTextChanged` via `Qt.callLater`. Static when text fits.
- [x] Track text: `artist + " — " + title` (em dash); just `title` when artist empty.
- [x] Volume button: `Layout.fillWidth` `Rectangle`. Label `"M"` (`textMuted`) when muted, `"N%"` (`textSecondary`) otherwise. Click = mute toggle (saves/restores `_savedVolume`). `WheelHandler` ±0.05 per tick.

**Wiring:**
- [x] `FifoListener.qml` — `toggleMediaPlayerRequested` signal + `"toggleMediaPlayer"` dispatch.
- [x] `PanelController.panelOrder` — `["calendar", "mediaPlayer", "settings", "wallpaper"]`.
- [x] `PanelSurface.qml` — `mprisProcess` property; `"mediaPlayer"` Loader case; `onLoaded` injection.
- [x] `shell.qml` — `onToggleMediaPlayerRequested`; `mprisProcess: mpris` on `PanelSurface`.
- [x] labwc `rc.xml` — **W-3** → `toggleMediaPlayer`.

**Key decisions:**
- No progress bar, no track time, no duration — MPRIS seek is unreliable across players.
- Volume via `MprisPlayer.volume` (read/write); tagged as fix candidate — some players (browser-based) ignore volume writes.
- `desktopEntry` used for window focus; matches Wayland `app_id` for all tested players.

---

## Wallpaper Panel — W-5

Data layer + panel UI, wired end-to-end. Further testing and touch-up pending; video thumbnail extraction deferred to v2.

**Data layer — `WallpaperProcess.qml`:**
- [x] Reads initial state from `Prefs` (`wallpaperSourceType`, `wallpaperPath`, `wallpaperColor`, `wallpaperDir`, `slideshowInterval`) on startup.
- [x] `setColor(hex)` — updates `sourceType`, persists to Prefs. No yin call — color Rectangle in shell.qml handles rendering.
- [x] `setImage(path)` / `setVideo(path)` — updates state, persists to Prefs, calls `yinctl --img <path>` via short-lived `Process`.
- [x] `startSlideshow(files)` / `nextSlide()` / `stopSlideshow()` — interval `Timer` cycles ordered file list. `setSlideshowInterval(secs)` persists the interval.
- [x] `scanDirectory(dir)` — runs `find <dir> -maxdepth 1 -type f`, splits output into `imageFiles` and `videoFiles` arrays by extension. Sorted alphabetically.
- [x] Startup restore: if `sourceType` is image/video and `wallpaperPath` is non-empty, calls `yinctl --img <wallpaperPath>` on `Component.onCompleted`. More reliable than `yinctl --restore` (doesn't depend on yin's cache).
- [x] `lastError` property — set to `"yin not started"` on non-zero yinctl exit; cleared on success.
- [x] `Prefs` extended: `wallpaperSourceType`, `wallpaperPath`, `wallpaperColor`, `wallpaperDir`, `slideshowInterval`.
- [x] `root-processes/qmldir` — added `singleton Prefs` so `WallpaperProcess` can access it directly.

**Color background — `shell.qml`:**
- [x] `PanelWindow` at `WlrLayer.Background`, `exclusiveZone: -1`, fills screen, `color: wallpaper.currentColor`, `visible: wallpaper.sourceType === "color"`. Handles solid color without involving yin. yin keeps running underneath (invisible) — switching back to image/video reveals yin without a new yinctl call.

**Panel UI — `WallpaperPanel.qml`:**
- [x] `PanelNavBar` as first row (consistent with all panels except WindowSwitcher).
- [x] Background `Rectangle` (`panelBgColor`, `radLg`, `panelBorderColor`) matching other panels.
- [x] **Color tab:** 24 preset swatches in a 6×4 grid. Active swatch = accent border. Tooltips show color name. Click applies immediately.
- [x] **Media tab:** directory `TextInput` + Scan `PanelButton`; Images section with `Single | Slideshow` `TogglePair`; slideshow interval stepper (±5s, min 5s); Apply button (starts slideshow with selection, or all images if none selected); 3-row horizontally-scrollable image grid (real async thumbnails, filename labels, checkmark on slideshow-selected tiles); Video/GIF section (same grid, play icon placeholder); empty-state text; `lastError` text.

**Wiring:**
- [x] `root-processes/qmldir` — `WallpaperProcess 1.0` registered.
- [x] `FifoListener` — `toggleWallpaperRequested` signal + `"toggleWallpaper"` dispatch.
- [x] `PanelController.panelOrder` — `"wallpaper"` appended: `["calendar", "settings", "wallpaper"]`.
- [x] `PanelSurface` — `wallpaperProcess` property; `"wallpaper"` Loader case; `onLoaded` injection.
- [x] `shell.qml` — `import Quickshell.Wayland`; `WallpaperProcess { id: wallpaper }`; color bg window; `onToggleWallpaperRequested`; `wallpaperProcess: wallpaper` on PanelSurface.
- [x] `module-panels/qmldir` — `WallpaperPanel 1.0` registered.
- [x] labwc `rc.xml` — **W-5** → `toggleWallpaper`.

---

## Settings Panel — Appearance Tab

Full Appearance tab built and wired. Live-updating — all preference changes apply on the same frame.

- [x] Tab bar `TogglePair` added to `SettingsPanel` (`"services"` / `"appearance"` state).
- [x] **Typography card:** steppers for `fontSizePill` (10–18) and `fontSizeBase` (8–14); text inputs for `fontMono` and `fontNerd` (apply on Enter/blur).
- [x] **Corner rounding card:** three-way selector → `Prefs.radiusScale` (0.0 / 0.5 / 1.0).
- [x] **Borders card:** two three-way selectors → `Prefs.borderWidth` (0/1/2) and `Prefs.elementBorderWidth` (0/1/2).
- [x] **Reset to defaults:** `PanelButton { variant: "critical" }` — calls all `Prefs.set*()` with defaults.
- [x] `Prefs.qml` created — `pragma Singleton`, `QtCore.Settings` block, 7 appearance properties with setters.
- [x] `Style.qml` extended — Prefs-derived Fixed section (`fontSizeBody`, `radSm/Md/Lg`, `borderWidth`, `elementBorderWidth`). Old aliases kept for backward compat at this point — subsequently cleaned up (see Style.qml Cleanup entry below).

---

## Style.qml — Backward-Compat Cleanup

Removed all legacy aliases that were kept during the Appearance Tab build. Style.qml now contains only the current token set.

- [x] Text tokens collapsed: `textLight`, `textButton` → `textSecondary`; `textSubtle`, `textDim` → `textMuted`; `textAccentColor` → `textAccent`.
- [x] Single-use font size tokens removed: `fontTimerSize`, `fontNavSize`, `fontGridNumSize`, `fontLabelSize`, `fontWeatherIcon` — moved inline to their respective components or replaced with `Style.fontSizeSubtle`.
- [x] Raw size scale removed: `sizeXl`, `sizeLg`, `sizeMd`, `sizeSm`, `sizeXs`, `sizeXxs`, `sizeLabel`.
- [x] Legacy radius tokens removed: `pillBorderRadius`, `panelBorderRadius`, `radButton`, `radButtonSmall`, `radGridToday`, `radGridTooltip`, `radLight`, `radHigh` — all components now use `radSm` / `radMd` / `radLg`.
- [x] Border primitives removed: `borderNone`, `borderThin`, `borderThick` — replaced by `Style.borderWidth` / `Style.elementBorderWidth`.

---

## Settings Panel — Services Tab

Data layer + Services UI, wired end-to-end.

**Data layer:**
- [x] `SettingsProcess.qml` — `QtCore.Settings` singleton → `~/.config/pillbox/pillbox.conf`. Properties: `googleConnected`, `locationMode`, `locationString`. Methods: `disconnect()`, `reconnect()`, setters. Signal: `googleDisconnected`.
- [x] `CalendarProcess` + `TasksProcess` — added `lastError` (`""` / `"auth"` / `"network"`), `clearData()`, fetch guard when `googleConnected = false`, `googleDisconnected` listener.
- [x] `gcal_fetch.py` — `--revoke` flag: server-side POST to `oauth2.googleapis.com/revoke` + local token file deletion.
- [x] `WeatherProcess` — injected `settingsProcess`; dynamic `command` builds `--location` arg; re-fetches on location change.
- [x] `weather_fetch.py` — `--location` flag: city name resolved via Open-Meteo geocoding, or `lat,lon` parsed directly.

**Panel UI:**
- [x] Google Account card: connected/not-connected status dot, per-service last-fetch + error label, Re-authenticate and Connect buttons, Disconnect button.
- [x] Weather Location card: Auto/Manual `TogglePair`, manual `TextInput` + Apply wired to `settingsProcess.setLocationString`.

**Wiring:**
- [x] `FifoListener` — `toggleSettings` signal + dispatch.
- [x] `PanelSurface` — `"settings"` Loader case; `WlrKeyboardFocus.Exclusive` for all panels.
- [x] `shell.qml` — `SettingsProcess { id: settings }` instantiated; forwarded to CalendarProcess, TasksProcess, WeatherProcess, PanelSurface.
- [x] labwc — **W-4** → `toggleSettings`. W-3 reserved for Media Player.

---

## Reusable Components

Six visual components + PanelNavBar built and registered. Full specs in [components.md](components.md).

- [x] `PanelButton` — 3 variants (default / accent / critical), content-driven width, HoverHandler.
- [x] `PanelCard` — raised section container. `default property alias` removed due to Qt 6.11 crash; callers provide their own ColumnLayout.
- [x] `PanelDivider` — 1px horizontal rule.
- [x] `SectionLabel` — all-caps tracking label.
- [x] `StatusDot` — 8×8 status circle, green/red.
- [x] `TogglePair` — exclusive two-button toggle. Per-corner radius (Qt 6.7+).
- [x] `IconButton` — compact Nerd Font glyph button. Added `fontFamily` property for glyph vs. mono switching.
- [x] `PanelNavBar` — standard first-row ‹/› navigation, right-aligned. Required for all panels except WindowSwitcher.

---

## Calendar Panel

Data layer + panel UI + three views, wired end-to-end.

**Data layer:**
- [x] `CalendarProcess` — gcal-fetch subprocess, exposes `nextEvent`, `todayEvents`, `weekEvents`, `eventsByDate`, `lastUpdated`. 10s startup delay, 5-minute repeat cycle, immediate on `refreshCalendar`.
- [x] `TasksProcess` — gtask-fetch subprocess, exposes `todayTasks`, `weekTasks`, `overdueTasks`, `tasksByDate`.
- [x] `WeatherProcess` — weather-fetch subprocess (Open-Meteo, keyless), exposes `current` and `forecast` (7-day array).
- [x] `gcal-fetch` — Python, Google Calendar API, shared auth with gtask-fetch.
- [x] `gtask-fetch` — Python, Google Tasks API.
- [x] `google-auth-notify` — re-auth notification with action button.
- [x] `weather-fetch` — Python, Open-Meteo + ipapi.co (24h cached).
- [x] `TimerProcess` rewrite — 50ms tick, `displayText: "HH:MM:SS"`, `displayCenti`, `setMode(m)`, drift-free `Date.now()` delta tracking.

**Infrastructure:**
- [x] `PanelController.qml` — `toggle(panelId)`, `navigate(direction)`, `panelOrder`.
- [x] `PanelSurface.qml` — content-driven height (capped at `Screen.height - 2 * panelY`), ESC dismiss, left/right key navigation, click-outside dismiss, `WlrKeyboardFocus.Exclusive`, Loader source switching.
- [x] `FifoListener` — `toggleCalendar` dispatch.
- [x] labwc — **W-2** → `toggleCalendar`.

**Panel UI:**
- [x] `CalendarPanel.qml` — three views (glance / expanded / timer), month grid with dot indicators, month navigation, 7-day schedule + tasks + forecast in expanded view.
- [x] `TimerWidget.qml` — large HH:MM:SS display, mode toggle, start/stop, duration input (free-form `Xh:Xm:Xs` parsing, Enter/blur confirms), WheelHandler scroll-to-adjust, reset.
- [x] Layout refactor — `Column`/`Row`/`Grid` with manual x arithmetic → `ColumnLayout`/`RowLayout`/`GridLayout` with `anchors.margins: 12`.

---

## Window Switcher Panel

- [x] `ToplevelProcess` — `ObjectModel<Toplevel>` from `ToplevelManager`, `focused` = `activeToplevel`.
- [x] `WindowPill` — glyph + `focused.appId`, visible only while switcher is open.
- [x] `WindowSwitcherPanel` — `FocusScope`, live filter `TextInput`, keyboard nav (↑↓ Enter Escape), `toplevel.activate()` (no subprocess), app glyph map (13 categories + fallback), `dismissed()` signal.
- [x] `PanelSurface` — `toplevelProcess` property, `dismissRequested()` signal wired.
- [x] labwc — **W-Tab** → `toggleWindowSwitcher` (was `rofi -show window`).

---

## MPRIS Pill

- [x] `MprisProcess` — `Mpris.players` `ObjectModel`, `_selectPlayer()` (Playing > Paused > first), `playerUpdated` signal.
- [x] `MprisPill` — `priority: 5/0` based on playback state, 3-second peek on `playerUpdated`, `visualComponent` with playback glyph + track title.
- [x] Glyph corruption fix — embedded raw Unicode bytes replaced with `String.fromCodePoint(0xXXXX)` calls throughout MprisPill, WindowPill, WindowSwitcherPanel.
- [x] CJK font fallback — `fontCJK: "Sarasa Mono SC"` added to Style. Handled transparently by Qt via fontconfig.

---

## PillWindow — Content-Driven Width

- [x] `PillWindow.implicitWidth` changed from hardcoded `Screen.width * 0.10` to `(contentLoader.item ? contentLoader.item.implicitWidth : 0) + 40`.
- [x] `Loader` inside `PillWindow` now uses `width: item ? item.implicitWidth : 0` — each pill declares its natural width.
- [x] `anchors.left` / `anchors.right` removed from `PillWindow` — layer-shell centers automatically when only `anchors.top` is set.
- [x] Pills drop `anchors.fill: parent` / `anchors.centerIn: parent` in their `visualComponent`; keep only `anchors.verticalCenter: parent.verticalCenter`.
- [x] Variable-length pills (`MprisPill`, `WindowPill`) cap text at `width: Math.min(implicitWidth, 200)` with `elide: Text.ElideRight`.

---

## PillController — Priority-Based Winner + W-1 Latch

- [x] Replaced hardcoded `if`-chain Stage 1 winner with `priority`-based max-picker. Each pill exposes `priority: int` + `shouldReveal: bool`. `PillController` never reads pill-specific properties.
- [x] W-1 latch changed from 5-second auto-expiring peek to persistent toggle. First press = `_peekActive = true`; second press = `_peekActive = false` + `_userDismissed = true`. `_peekTimer` removed entirely.

---

## Workspace Pill

- [x] `WorkspaceProcess` — `WindowManager.windowsets` binding, `current`, `list`, `currentIndex`, `workspaceChanged` signal.
- [x] `WorkspacePill` — 1.5-second `shouldReveal` window, workspace name + radiobox glyphs `visualComponent`.
- [x] `PillWindow` switched from hardcoded `Text` to `Loader { sourceComponent: activePill.visualComponent }`.

---

## Style.qml — Palette Redesign

- [x] Interpolated grayscale ramp → standard Nord terminal palette (nord0–nord15 in terminal-color order). Same format as pywal/matugen output.
- [x] Separate Accent Palette removed — frost blues folded into color7–color10, aurora accents into color11–color15.
- [x] Radius tokens simplified: `radSm` / `radMd` / `radLg` (scale-driven by `Prefs.radiusScale`).
- [x] `accentBgColor` / `accentBgHover` derived via `Qt.darker(color10, …)` — no orphaned hex literals.
- [x] Added `textCritical` (color11) and `textSuccess` (color14).
- [x] All Fixed properties updated; `CalendarPanel.qml` wired to new token names (54 lines updated).
