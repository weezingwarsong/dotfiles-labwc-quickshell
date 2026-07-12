# Reusable Visual Components

Visual UI building blocks in `module-reusable-elements/` shared across all panels.

All tokens come from `Style.qml`; user-adjustable values flow through `Prefs.qml`.
See [style-system.md](style-system.md) for the full token system.

---

## PanelNavBar

**Purpose:** Standard first row for all panels (except WindowSwitcher). Two arrow buttons — `‹` (prev) and `›` (next) — right-aligned. Clicking navigates through `panelOrder` via `PanelSurface → PanelController.navigate()`.

This line is always the **first child** of every panel's root `ColumnLayout`.

**Signal:**

| Signal | Notes |
|---|---|
| `navigateRequested(int direction)` | `-1` = prev, `+1` = next. Caller forwards to `root.navigateRequested`. |

**Call site:**
```qml
PanelNavBar { onNavigateRequested: (dir) => root.navigateRequested(dir) }
```

**Used in:** CalendarPanel, MediaPlayerPanel, NotificationPanel, ControlPanel, SettingsPanel, WallpaperPanel (all non-switcher panels)

---

## PanelButton

**Purpose:** Labelled action button with optional Nerd Font glyph prefix, hover state, and three visual variants.

**Props:**

| Prop | Type | Default | Notes |
|---|---|---|---|
| `label` | `string` | `""` | Button text. Optional — defaults to empty string. |
| `icon` | `string` | `""` | Optional Nerd Font glyph rendered before label. Hidden when empty. |
| `variant` | `string` | `"default"` | `"default"` · `"accent"` · `"critical"` |
| `signal clicked()` | — | — | Emitted via `TapHandler` on tap |

Width is content-driven (`label` + `icon` widths + 20px horizontal padding). `HoverHandler` drives hover state; `TapHandler` handles clicks.

**Variant colours:**

| Variant | Bg (rest) | Bg (hover) | Text |
|---|---|---|---|
| `default` | transparent | `Style.surfaceLowColor` | `Style.textSecondary` |
| `accent` | `Style.accentBgColor` | `Style.accentBgHover` | `Style.textMuted` |
| `critical` | transparent | `Style.criticalBgColor` | `Style.textCritical` |

**Tokens:** `Style.buttonHeight`, `Style.fontMono`, `Style.fontSizeBody`, `Style.radSm`, `Style.borderSoftColor`, `Prefs.elementBorderWidth`

**Call site:**
```qml
PanelButton { label: "More ↓"; onClicked: root.showMore() }
PanelButton { label: "Re-authenticate"; variant: "accent"; onClicked: root.startAuth() }
PanelButton { label: "Disconnect"; variant: "critical"; onClicked: root.disconnect() }
```

**Used in:** CalendarPanel ×3, SettingsPanel ×3, Appearance tab ×many, WallpaperPanel ×4 (Scan, –, +, Apply)

---

## PanelCard

**Purpose:** Raised section container. Groups related settings or content into a visually distinct block.

**Props:**

| Prop | Type | Default | Notes |
|---|---|---|---|
| `padding` | `int` | `12` | Inner margin on all sides |

**Visual:** `surfaceLowColor` background, `radLg` corners, `borderFaintColor` border.

**Important:** `PanelCard` is visual chrome only — it provides the styled Rectangle and sizes itself to `childrenRect`. Callers place their own `ColumnLayout` inside, positioned at `y: parent.padding` with left/right anchors. This avoids a Qt 6.11 crash where `default property alias` to a sub-item's `data` property causes `bad_function_call` during binding finalization.

**Call site:**
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

**Used in:** SettingsPanel ×2 (Google Account, Weather Location), Appearance tab ×3 (Typography, Corner rounding, Borders)

---

## PanelDivider

**Purpose:** Full-width 1px horizontal rule between sections in a panel.

**Props:** none

**Tokens:** `Style.panelDividerColor`

**Call site:**
```qml
PanelDivider {}
```

**Used in:** CalendarPanel ×2, SettingsPanel ×1, WallpaperPanel ×1

---

## SectionLabel

**Purpose:** Small all-caps tracking label that introduces a panel section (EVENTS TODAY, DIRECTORY, etc.).

**Props:**

| Prop | Type | Required | Notes |
|---|---|---|---|
| `text` | `string` | yes | Component uppercases via `Font.AllUppercase` |

**Tokens:** `Style.fontMono`, `Style.fontSizeSubtle`, `Style.textMuted`

Root element is a plain `Text` — no wrapping Rectangle. Also applies `font.letterSpacing: 1` (hardcoded, not a Style token).

**Call site:**
```qml
SectionLabel { text: "Events Today" }
SectionLabel { text: "Directory" }
```

**Used in:** CalendarPanel ×4, SettingsPanel ×2, WallpaperPanel ×4

---

## StatusDot

**Purpose:** Small filled circle indicating a binary connected/active state.

**Props:**

| Prop | Type | Required | Notes |
|---|---|---|---|
| `active` | `bool` | yes | `true` → success color; `false` → critical color |

**Visual:** 8×8px, `radius: 4` (hardcoded). `Style.textSuccess` when active, `Style.textCritical` when not.

**Call site:**
```qml
StatusDot { active: settingsProcess.googleConnected }
```

**Used in:** SettingsPanel ×1 (Google account status)

---

## TogglePair

**Purpose:** Two adjacent buttons where exactly one is always selected — an exclusive pair toggle.

**Props:**

| Prop | Type | Required | Notes |
|---|---|---|---|
| `labelA` | `string` | yes | Left button label |
| `labelB` | `string` | yes | Right button label |
| `selected` | `int` | yes | `0` = A active, `1` = B active. Parent owns and updates this. |
| `signal toggled(int index)` | — | — | Emitted on click with tapped index. Parent updates `selected`. |

`Layout.fillWidth: true` is set on the root item — no need to repeat it at call sites.

Corner treatment: one outer `Rectangle` with `radius: radSm` provides the full border. Two inner selection highlight `Rectangle`s use per-corner radius (`topLeftRadius`/`bottomLeftRadius` for A, `topRightRadius`/`bottomRightRadius` for B) so the active side has rounded outer corners and a square inner edge. A centre divider `Rectangle` renders the split line. Requires Qt 6.7+.

`toggled(index)` only fires when the tapped side differs from the current `selected` value — tapping the already-active side is a no-op.

**State colours:**

| State | Bg | Text |
|---|---|---|
| Selected | `Style.accentBgColor` | `Style.textMuted` |
| Unselected | transparent | `Style.textSecondary` |

**Tokens:** `Style.buttonHeight`, `Style.fontMono`, `Style.fontSizeBody`, `Style.radSm`, `Style.borderSoftColor`, `Prefs.elementBorderWidth`

**Call site:**
```qml
TogglePair {
    labelA: "Auto"
    labelB: "Manual"
    selected: settingsProcess.locationMode === "manual" ? 1 : 0
    onToggled: (i) => settingsProcess.setLocationMode(i === 0 ? "auto" : "manual")
}
```

**Used in:** SettingsPanel ×2 (location mode, tab bar), Appearance tab (tab bar), WallpaperPanel ×2 (Color/Media tab bar, Single/Slideshow)

---

## IconButton

**Purpose:** Compact Nerd Font glyph button. Used internally by `PanelNavBar` for the ‹ and › navigation arrows.

**Props:**

| Prop | Type | Notes |
|---|---|---|
| `label` | `string` | The glyph or text to display |
| `fontFamily` | `string` | Defaults to `Style.fontNerd` — covers both regular text and glyph codepoints |
| `signal clicked()` | — | Emitted on tap |

**Used in:** PanelNavBar ×2 (‹ ›), MediaPlayerPanel ×2 (prev/next track buttons)

---

## ScrollingText

**Purpose:** Clipped `Item` that scrolls its text label left when content overflows the available width. Handles the pause-scroll-pause-snap animation loop internally.

**Props:**

| Prop | Type | Default | Notes |
|---|---|---|---|
| `text` | `string` | `""` | The text content |
| `color` | `color` | `Style.textPrimary` | Text color |
| `maxWidth` | `int` | `9999` | Caps `implicitWidth`; pills set this to `200` |
| `pauseDuration` | `int` | `1500` | Ms to pause at each end before animating |
| `speed` | `int` | `20` | Ms per pixel of overflow |
| `font` | `font` | (alias) | Full font alias — set `font.family`, `font.pixelSize`, etc. |

`implicitWidth` is `min(label.implicitWidth, maxWidth)`. When `implicitWidth ≤ parent.width` no animation runs — text is static and left-aligned. Animation restarts automatically on `text` change.

**Animation:** `SequentialAnimation` — pause → scroll left to `-(overflow)` at `speed` ms/px → pause → snap back to 0 instantly. Runs only while the item is visible and overflowing.

**Call site:**
```qml
ScrollingText {
    text:     root._player ? root._player.trackArtist + " — " + root._player.trackTitle : ""
    color:    Style.textNormal
    maxWidth: 200
    font.family:    Style.fontMono
    font.pixelSize: Style.fontSizeBody
}
```

**Used in:** MprisPill (track text), TimePill (calendar-imminent marquee), WindowPill (app id)

---

## Implementation Notes

- **PanelCard** — `default property alias` to a sub-item's `data` removed due to Qt 6.11 crash (`bad_function_call` in `lookupSingletonProperty` during binding finalization). Now visual-chrome-only; callers provide their own `ColumnLayout`.
- **TogglePair** and **PanelDivider** — both need `import QtQuick.Layouts` even though they only use `Layout.fillWidth`. The `Layout` attached property requires the Layouts module imported in the file that uses it.
- **SectionLabel** — root element is a plain `Text`; it does not wrap another `Text`.
- **PanelNavBar** — must be the first child of every panel's root `ColumnLayout`. WindowSwitcherPanel is the only exception — it has its own dismiss/navigation model.

---

## Candidates to Add

These behaviors are shared across all panels but are currently implemented inline in `PanelSurface` rather than as discrete reusable components. Worth investigating whether they should be extracted.

### ESC to dismiss

**Current state:** `Keys.onEscapePressed` is handled inside `PanelSurface`'s Loader `onLoaded` block — the loaded panel item captures the key event and emits `dismissRequested()`.

**Intent:** ESC dismisses the active panel. This is universal across all panels. Whether it stays in `PanelSurface` or gets extracted is open — the key question is whether any future panel would need to override or suppress the default ESC behavior. If yes, it should be a composable piece; if no, keeping it in `PanelSurface` is fine.

### Click-outside to dismiss

**Current state:** A fullscreen `MouseArea` behind the panel content in `PanelSurface` emits `dismissRequested()` on click. Disabled for `windowSwitcher` (see [modules.md](modules.md) fix candidate).

**Intent:** Clicking anywhere outside the panel content dismisses it. Universal across all panels including WindowSwitcher (once the WindowSwitcher fix candidate is resolved). Same question as ESC — decide whether to extract once WindowSwitcher is fixed and the full behavior is confirmed consistent.
