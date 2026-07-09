# Completed Work Log

Reverse-chronological. Each entry describes what was built and key decisions made, for future reference and audit.

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
