# Reusable Visual Components ✓

Visual UI building blocks in `module-reusable-elements/` — all built and wired into panels.
Distinct from the architectural elements (PillController, PillWindow, HoverZone, PanelController,
PanelSurface), which own no visual opinions. These components own visual opinions and reference
design tokens directly.

All tokens come from `Style.qml`; user-adjustable values flow through `Prefs.qml`.
See [settings.md](settings.md) for the full token system design.

---

## Components

### PanelNavBar

**Purpose:** Standard first-row navigation bar for all panels (except WindowSwitcher). Two arrow buttons — `‹` (prev) and `›` (next) — right-aligned in a fill-width row. Clicking navigates through `panelOrder` via `PanelSurface → PanelController.navigate()`.

**Props:**

| Signal | Notes |
|---|---|
| `signal navigateRequested(int direction)` | Emitted with `-1` (prev) or `+1` (next). Caller forwards to `root.navigateRequested`. |

**Tokens used:** inherits from `IconButton` (same tokens: `Style.fontNerd`, `Style.fontSizeBody`, `Style.buttonHeight`, `Style.radSm`, `Style.borderSoftColor`).

**Call site:**
```qml
PanelNavBar { onNavigateRequested: (dir) => root.navigateRequested(dir) }
```

This line is the **first child** of every panel's root `ColumnLayout`, placing the arrows consistently at the top-right of all panels. WindowSwitcherPanel is excluded — it has its own dismiss path.

**Used in:** CalendarPanel ×1, SettingsPanel ×1, WallpaperPanel ×1

---

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

**Used in:** CalendarPanel ×2, SettingsPanel ×1, WallpaperPanel ×1

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

**Used in:** CalendarPanel ×4, SettingsPanel ×2, WallpaperPanel ×4

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

**Used in:** CalendarPanel ×3 (More ↓, Timer, Edit ↗), SettingsPanel ×3 (Re-authenticate, Disconnect, Apply), Appearance tab ×many (steppers, 3-way selectors, Reset), WallpaperPanel ×4 (Scan, –, +, Apply)

---

### PanelCard

**Purpose:** Raised section container — `surfaceLowColor` background, rounded corners, optional
border. Used to group related settings or content into a visually distinct block within a panel.

**Props:**

| Prop | Type | Default | Notes |
|---|---|---|---|
| `padding` | `int` | `12` | Inner margin on all sides |

**Tokens used:**
| Token | Role |
|---|---|
| `Style.surfaceLowColor` | Background fill |
| `Style.radLg` | Corner radius |
| `Style.borderFaintColor` | Border color |
| `Style.borderWidth` | Border width |

`PanelCard` is **visual chrome only** — it provides the styled Rectangle background and sizes
itself to its content via `childrenRect`. Callers place their own `ColumnLayout` inside,
positioned at `y: parent.padding` with left/right anchors. This avoids a Qt 6.11 crash where
`default property alias` to a sub-item's `data` property causes `bad_function_call` during
binding finalization.

`Layout.fillWidth: true`. Height: `childrenRect.y + childrenRect.height + padding`.

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
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8
        // ... children
    }
}
```

After:
```qml
PanelCard {
    ColumnLayout {
        y: parent.padding
        anchors { left: parent.left; right: parent.right; margins: parent.padding }
        spacing: 8
        StatusDot { active: settingsProcess.googleConnected }
        PanelButton { label: "Disconnect"; variant: "critical"; onClicked: … }
    }
}
```

**Used in:** SettingsPanel ×2 (Google Account, Weather Location), Appearance tab ×3 (Typography,
Corner rounding, Borders)

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

**Used in:** SettingsPanel ×2 (location mode toggle, tab bar), Appearance tab tab bar, WallpaperPanel ×2 (Color/Media tab bar, Single/Slideshow toggle)

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

## Implementation notes

All six components are built. Key decisions recorded here for future reference:

- **PanelCard** — `default property alias` to a sub-item's `data` was removed due to a Qt 6.11 crash (`bad_function_call` in `lookupSingletonProperty` during binding finalization). Now visual-chrome-only; callers provide their own `ColumnLayout`.
- **TogglePair** and **PanelDivider** — both need `import QtQuick.Layouts` even though they only use `Layout.fillWidth`. The `Layout` attached property requires the Layouts module imported in the file that uses it.
- **SectionLabel** — root element is a plain `Text`; it doesn't wrap another `Text`.
