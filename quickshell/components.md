# Reusable Visual Components

Specs for the next phase of `module-reusable-elements/` — the visual UI building blocks shared
across all panels. These are distinct from the architectural elements already built
(PillController, PillWindow, HoverZone, PanelController, PanelSurface), which own no visual
opinions. These components own visual opinions and reference design tokens directly.

**Dependency:** All components reference tokens from `Style.qml` (refactored) and `Prefs.qml`
(new). Neither exists in final form yet. Build order:

```
Prefs.qml → Style.qml refactor → these components → panel refactors
```

See [settings.md](settings.md) for the full token system design.

---

## Components

### PanelDivider

**Purpose:** Full-width 1px horizontal rule between sections in a panel.

**Props:** none

**Tokens used:**
| Token | Role |
|---|---|
| `Style.panelDividerColor` | Rule color |

**Call site:**

Before:
```qml
Rectangle {
    Layout.fillWidth: true
    height: 1
    color: Style.panelDividerColor
}
```

After:
```qml
PanelDivider {}
```

**Used in:** CalendarPanel ×2, SettingsPanel ×1

---

### SectionLabel

**Purpose:** Small all-caps tracking label that introduces a panel section
(EVENTS TODAY, TASKS THIS WEEK, etc.).

**Props:**

| Prop | Type | Required | Notes |
|---|---|---|---|
| `text` | `string` | yes | Passed as-is; component uppercases via `Font.AllUppercase` |

**Tokens used:**
| Token | Role |
|---|---|
| `Style.fontMono` | Font family |
| `Style.fontSizeSubtle` | Pixel size |
| `Style.textMuted` | Text color — structural, de-emphasised |

**Call site:**

Before:
```qml
Text {
    text: "EVENTS TODAY"
    font.family: Style.fontMono
    font.pixelSize: Style.fontLabelSize
    font.letterSpacing: 1
    color: Style.textSubtle
}
```

After:
```qml
SectionLabel { text: "Events Today" }
```

**Used in:** CalendarPanel ×4, SettingsPanel ×2

---

### PanelButton

**Purpose:** Labelled action button with optional Nerd Font glyph prefix, hover state, and
three visual variants.

**Props:**

| Prop | Type | Default | Notes |
|---|---|---|---|
| `label` | `string` | — | Required. Button text. |
| `icon` | `string` | `""` | Optional Nerd Font glyph rendered before the label. Hidden when empty. |
| `variant` | `string` | `"default"` | `"default"` · `"accent"` · `"critical"` |
| `signal clicked()` | — | — | Emitted on mouse release |

**Tokens used:**
| Token | Role |
|---|---|
| `Style.buttonHeight` | Fixed height (22) |
| `Style.fontMono` | Font family |
| `Style.fontSizeBody` | Text size |
| `Style.radSm` | Corner radius |
| `Style.borderSoftColor` | Border color |
| `Prefs.elementBorderWidth` | Border width |

**Variant colours:**

| Variant | Bg (rest) | Bg (hover) | Text |
|---|---|---|---|
| `default` | transparent | `Style.surfaceLowColor` | `Style.textSecondary` |
| `accent` | `Style.accentBgColor` | `Style.accentBgHover` | `Style.textMuted` |
| `critical` | transparent | `Style.criticalBgColor` | `Style.textCritical` |

Width is content-driven (`label` + `icon` widths + horizontal padding). `HoverHandler` drives
hover state — no `MouseArea.hoverEnabled` pattern.

**Call site:**

Before (default button in CalendarPanel):
```qml
Rectangle {
    implicitWidth: _label.implicitWidth + 20
    implicitHeight: 22
    radius: Style.radLight
    border.width: 1
    border.color: Style.borderSoftColor
    color: _area.containsMouse ? Style.surfaceLowColor : "transparent"
    Text {
        id: _label
        anchors.centerIn: parent
        text: "More ↓"
        font.family: Style.fontMono
        font.pixelSize: Style.fontContentSize
        color: Style.textLight
    }
    MouseArea {
        id: _area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.showMore()
    }
}
```

After:
```qml
PanelButton {
    label: "More ↓"
    onClicked: root.showMore()
}
```

Accent variant (SettingsPanel "Re-authenticate"):
```qml
PanelButton {
    label: "Re-authenticate"
    variant: "accent"
    onClicked: root.startAuth()
}
```

**Used in:** CalendarPanel ×3 (More ↓, Timer, Edit ↗), SettingsPanel ×4 (Re-authenticate,
Disconnect, Apply ×2), Appearance tab (Save, Reset)

---

### PanelCard

**Purpose:** Raised section container — `surfaceLowColor` background, rounded corners, optional
border. Children are arranged in an internal `ColumnLayout`. Used to group related settings or
content into a visually distinct block within a panel.

**Props:**

| Prop | Type | Default | Notes |
|---|---|---|---|
| `padding` | `int` | `12` | Inner margin on all sides |
| `default` (children) | — | — | Routed into the internal `ColumnLayout` |

**Tokens used:**
| Token | Role |
|---|---|
| `Style.surfaceLowColor` | Background fill |
| `Style.radLg` | Corner radius |
| `Style.borderFaintColor` | Border color |
| `Prefs.borderWidth` | Border width |

Internal layout: `ColumnLayout { spacing: 8 }` anchored inside with `padding` margins.
Height is content-driven (`_col.implicitHeight + padding * 2`). `Layout.fillWidth: true`.

**Call site:**

Before (Google Account card in SettingsPanel):
```qml
Rectangle {
    Layout.fillWidth: true
    color: Style.surfaceLowColor
    radius: Style.radLg
    implicitHeight: _col.implicitHeight + 16
    ColumnLayout {
        id: _col
        anchors {
            left: parent.left; right: parent.right
            top: parent.top; margins: 12
        }
        spacing: 8
        // ... children
    }
}
```

After:
```qml
PanelCard {
    // children directly — rendered in internal ColumnLayout
    SectionLabel { text: "Google Account" }
    StatusDot { active: settingsProcess.googleConnected }
    PanelButton { label: "Disconnect"; variant: "critical"; onClicked: … }
}
```

**Used in:** SettingsPanel ×2 (Google Account, Weather Location), Appearance tab ×2+ (Palette,
Typography)

---

### TogglePair

**Purpose:** Two adjacent buttons where exactly one is always selected — an exclusive pair
toggle. Used for binary preference switches (Auto / Manual, Countdown / Countup).

**Props:**

| Prop | Type | Required | Notes |
|---|---|---|---|
| `labelA` | `string` | yes | Left button label |
| `labelB` | `string` | yes | Right button label |
| `selected` | `int` | yes | `0` = A active, `1` = B active. Parent owns and updates this. |
| `signal toggled(int index)` | — | — | Emitted on click with the tapped index (0 or 1). Parent updates `selected` in response. |

**Tokens used:**
| Token | Role |
|---|---|
| `Style.buttonHeight` | Height of both buttons |
| `Style.fontMono` | Font family |
| `Style.fontSizeBody` | Text size |
| `Style.radSm` | Outer corner radius |
| `Style.borderSoftColor` | Border color |
| `Prefs.elementBorderWidth` | Border width |

**State colours:**

| State | Bg | Text |
|---|---|---|
| Selected | `Style.accentBgColor` | `Style.textMuted` |
| Unselected | transparent | `Style.textSecondary` |

Corner treatment: outer corners use `radSm`; the shared inner edge uses per-corner radius
(`topRightRadius`/`bottomRightRadius: 0` on button A, `topLeftRadius`/`bottomLeftRadius: 0`
on button B). Requires Qt 6.7+, which Quickshell targets.

**Call site:**

Before (location mode toggle in SettingsPanel — 30+ lines):
```qml
// Two Rectangle + MouseArea blocks, repeated border logic, repeated hover state...
```

After:
```qml
TogglePair {
    labelA: "Auto"
    labelB: "Manual"
    selected: settingsProcess.locationMode === "manual" ? 1 : 0
    onToggled: (index) => settingsProcess.setLocationMode(index === 0 ? "auto" : "manual")
}
```

**Used in:** SettingsPanel ×1 (location mode), Appearance tab ×1+ (e.g. border on/off)

---

### StatusDot

**Purpose:** Small filled circle indicating a binary connected/active state. Green = active,
red = inactive.

**Props:**

| Prop | Type | Required | Notes |
|---|---|---|---|
| `active` | `bool` | yes | `true` → success color; `false` → critical color |

**Tokens used:**
| Token | Role |
|---|---|
| `Style.textSuccess` | Fill color when `active: true` |
| `Style.textCritical` | Fill color when `active: false` |

Size: 8×8px, `radius: width / 2`. No border.

**Call site:**

Before:
```qml
Rectangle {
    width: 8; height: 8
    radius: 4
    color: settingsProcess.googleConnected ? Style.textSuccess : Style.textCritical
}
```

After:
```qml
StatusDot { active: settingsProcess.googleConnected }
```

**Used in:** SettingsPanel ×1 (Google account status)

---

## Build order within this phase

1. `PanelDivider` — trivial, zero dependencies beyond `Style.panelDividerColor`
2. `SectionLabel` — trivial, three tokens
3. `StatusDot` — trivial, two tokens
4. `PanelButton` — medium; wires in `HoverHandler`, variant logic, `accentBgHover` first use
5. `PanelCard` — medium; content-driven height, default-property children routing
6. `TogglePair` — medium; per-corner radius, signal/property ownership pattern

Once all six exist: refactor panels to use them, which simultaneously validates the new
`Style.qml` token names in real components.
