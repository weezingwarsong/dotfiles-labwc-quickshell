# Reusable Visual Components

Building blocks in `module-reusable-elements/` shared across panels and pills.
All tokens come from `Style.qml`; user-adjustable values flow through `Prefs.qml`.

---

## PanelNavBar

Standard ‹ › navigation row. Always the **first child** of every panel's root layout. Wire `activePanel` so the nav bar knows which panel is open.

```qml
PanelNavBar {
    activePanel: root.activePanel
    onNavigateRequested: (dir) => root.navigateRequested(dir)
}
```

---

## PanelCard

Raised content container. Place a `ColumnLayout` with `anchors.left/right` inside for multi-row content. The card sizes itself to its children.

```qml
PanelCard {
    Layout.fillWidth: true
    ColumnLayout {
        anchors.left: parent.left; anchors.right: parent.right
        spacing: 8
        // rows ...
    }
}
```

---

## PanelButton

Labelled action button. `variant` controls appearance; `icon` is an optional Nerd Font glyph prefix.

```qml
PanelButton { label: "Connect";    variant: "accent";    onClicked: … }
PanelButton { label: "Disconnect"; variant: "critical";  onClicked: … }
PanelButton { label: "More";       icon: ""; onClicked: … }
```

---

## PanelDivider

Full-width 1 px horizontal rule. Drop between rows inside a card.

```qml
PanelDivider {}
```

---

## PanelTabBar

MD3 secondary tabs with an animated sliding accent underline. Pass a string array as `labels`; parent owns `selected`.

```qml
PanelTabBar {
    labels:   ["Appearance", "Services"]
    selected: root._tab === "services" ? 1 : 0
    onToggled: (i) => root._tab = (i === 0 ? "appearance" : "services")
}
```

---

## SectionHeader

Collapsible section heading with a chevron (▸ / ▾). Parent owns `collapsed`; toggle it in `onToggled`.

```qml
SectionHeader {
    Layout.fillWidth: true
    text:      "Typography"
    tooltip:   "Font sizes and families"
    collapsed: _typographyCollapsed
    onToggled: _typographyCollapsed = !_typographyCollapsed
}
```

---

## SectionLabel

Small all-caps tracking label for named sub-sections.

```qml
SectionLabel { text: "Events Today" }
```

---

## RowLabel

Label on the left, right-side control slot. `fill: false` (default) inserts a spacer to push the control to the right edge. `fill: true` omits the spacer so a `Layout.fillWidth` child can stretch.

```qml
// Right-aligned control
RowLabel { label: "Pill"
    ScrollChip { text: Prefs.pillRadius + "px"; onScrolled: … }
}

// Fill control
RowLabel { label: "Mono font"; fill: true
    FontPicker { Layout.fillWidth: true; value: Prefs.fontMono; onCommitted: … }
}
```

---

## TogglePair

Single-button toggle. Shows the current state at rest; on hover the label slides left revealing the alternative as a preview. Click flashes and switches.

`variant: "normal"` — equal weight for both options.
`variant: "yesno"` — `labelA` is the positive state (accent background); use for On/Off, Active/Stopped.

```qml
TogglePair {
    labelA: "Auto"; labelB: "Manual"
    selected: settingsProcess.locationMode === "manual" ? 1 : 0
    onToggled: (i) => settingsProcess.setLocationMode(i === 0 ? "auto" : "manual")
}

TogglePair {
    labelA: "On"; labelB: "Off"; variant: "yesno"
    selected: Prefs.extractColors ? 0 : 1
    onToggled: (i) => Prefs.setExtractColors(i === 0)
}
```

---

## ScrollChip

Scroll-wheel-adjustable value display. Show the current value; scroll up/down to increment or decrement. Clamp in `onScrolled`.

```qml
ScrollChip {
    text: Prefs.pillRadius + "px"
    onScrolled: (delta) => {
        var next = Prefs.pillRadius + delta
        if (next >= 0 && next <= 50) Prefs.setPillRadius(next)
    }
}
```

---

## FontPicker

Type-ahead font-family selector. Displays current value in an editable field; typing filters a dropdown list. Commit on Enter or list selection.

```qml
FontPicker {
    Layout.fillWidth: true
    value:       Prefs.fontMono
    onCommitted: (f) => Prefs.setFontMono(f)
}
```

---

## StatusDot

8 px filled circle for binary status. `textSuccess` when `active: true`, `textCritical` when false.

```qml
StatusDot { active: settingsProcess.googleConnected }
```

---

## IconButton

Compact glyph or text button. Used internally by `PanelNavBar`; also usable directly for media controls.

```qml
IconButton { label: ""; onClicked: player.previous() }
IconButton { label: ""; onClicked: player.next()     }
```

---

## ScrollingText

Clipped text that auto-scrolls when content overflows `maxWidth`. Handles pause → scroll → pause → snap internally.

```qml
ScrollingText {
    text:           root._player.trackTitle
    color:          Style.textNormal
    maxWidth:       200
    font.family:    Style.fontMono
    font.pixelSize: Style.fontSizeBody
}
```

---

## Carousel

Horizontal viewport-crop carousel for image/video selection. Three size tiers — HERO (current), NEAR (next/prev in travel direction), SMALL (further items) — animate width/height via `Behavior on Layout.preferredWidth/Height`. Each slot clips a horizontal strip of a single full-width image, producing a panorama-crop effect. Dim overlay (`#60000000`) fades in on inactive slots.

**Props:**

| Prop | Type | Notes |
|---|---|---|
| `model` | `var` | Array of `{path, name}` objects |
| `currentIndex` | `int` | Currently selected index; caller owns and drives this |
| `emptyText` | `string` | Shown centred when `model` is empty |
| `thumbsReady` | `var` | `path → true` map from `WallpaperProcess`; when set, thumbnails are used |
| `thumbPath` | `var` | `function(path) → string`; returns thumb JPEG path for a given source path |

**Signals:** `activated(int index)` — emitted on tap or scroll-wheel change.

**Sizing (from 16:9 wallpaper assumption):**
- `_nearH = width * 9/16` — image height as if panel equals wallpaper width
- `_nearW = _nearH * 9/16` — portrait 9:16 slot width for NEAR tier
- `_smallW = _nearW / 2` — SMALL tier
- `_heroH = _nearH` — HERO has equal height to NEAR (no zoom)
- HERO width fills whatever NEAR and SMALL leave behind

**Viewport crop model:** `Image` width = `root.width` (full carousel row), `x = -slot.x` (offsets to row origin), slot has `clip: true`. Each slot clips its horizontal strip. `fillMode` is default (`Stretch`) so the image scales to `root.width` before clipping — thumbnails at panel width make this accurate.

**Interaction:** `TapHandler` on each slot; `WheelHandler` on the row. Direction (`_direction`) is tracked for the NEAR slot selection — NEAR always points in the last travel direction.

```qml
Carousel {
    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
    model:       root.wallpaperProcess ? root.wallpaperProcess.imageFiles : []
    emptyText:   "No images in dir"
    thumbsReady: root.wallpaperProcess ? root.wallpaperProcess.thumbsReady : null
    thumbPath:   root.wallpaperProcess ? root.wallpaperProcess.thumbPath : null
    onActivated: (index) => root.wallpaperProcess.setImage(root.wallpaperProcess.imageFiles[index].path)
    onVisibleChanged: if (visible) currentIndex = root._findImageIdx()
}
```

---

## LocalTimer

Drop-in ephemeral timer backed by `LocalTimerProcess`. Registers itself on creation; fires `completed()` when done. Does **not** auto-kill on element destruction — call `kill()` explicitly if you need early termination.

**Props:**

| Prop | Type | Notes |
|---|---|---|
| `timerId` | `string` | Unique key. Required — empty string skips registration and logs an error. |
| `duration` | `int` | Duration in **milliseconds**. |
| `variant` | `int` | 1–5 (see below). Default 1. |
| `color` | `color` | Bar fill color. Default `Style.accentColor`. Two intended values: `Style.accentColor` / `Style.criticalColor`. |
| `localTimerProcess` | `var` | Injected reference to `LocalTimerProcess`. Required. |

**Signal:** `completed()` — fires once at expiry. Not fired when `kill()` is called.

**Function:** `kill()` — delegates to `localTimerProcess.kill(timerId)`.

**Variants:**

| Variant | Visual | Fill |
|---|---|---|
| 1 | None (zero implicit size) | — |
| 2 | `RowLayout`, 2px height, `fillWidth` | Grows right as time elapses |
| 3 | `ColumnLayout`, 2px width, `fillHeight` | Grows up from bottom as time elapses |
| 4 | `RowLayout`, 2px height, `fillWidth` | Shrinks from right as time remaining drops |
| 5 | `ColumnLayout`, 2px width, `fillHeight` | Shrinks from top as time remaining drops |

All bars animate with `SmoothedAnimation` — no raw 50ms jumps.

```qml
// Variant 1 — signal only
LocalTimer {
    timerId:            "my-effect"
    duration:           3000
    variant:            1
    localTimerProcess:  root.localTimerProcess
    onCompleted:        doSomething()
}

// Variant 4 — horizontal remaining bar, accent color
LocalTimer {
    timerId:            "toast-bar"
    duration:           5000
    variant:            4
    color:              Style.accentColor
    localTimerProcess:  root.localTimerProcess
    Layout.fillWidth:   true
}
```

**Design notes:**
- `timerId` must be unique across all active timers. Duplicate registration restarts the timer with the new `duration`.
- Duration is in milliseconds throughout — callers working in seconds multiply by 1000 at the callsite.
- The process tick runs only while timers are active (auto-stops when the map is empty).
