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
