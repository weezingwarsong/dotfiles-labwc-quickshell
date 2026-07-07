# Settings Panel — Design Notes

This file is the living design document for the Settings panel. All decisions, rationale,
and open questions live here. The README carries only a pointer.

---

## Status

| Area | State |
|---|---|
| Services tab | ✓ built and wired |
| Design system audit | ✓ complete |
| Reusable elements | ✓ built (PanelButton, PanelCard, PanelDivider, SectionLabel, StatusDot, TogglePair) |
| Appearance tab | ✓ built |

---

## Purpose

A centralized panel with two jobs:

- **Configuration** — provide Pillbox with the inputs it needs to function (OAuth tokens,
  location preferences).
- **Preferences** — tune how Pillbox looks and behaves (palette, timing constants).

Summoned deliberately via **W-4** (`toggleSettings` → FIFO). Not auto-revealed.

---

## Two-layer preference model

All settings operate on two layers:

- **Defaults** — the compiled-in baseline. Never written to disk. Represents a sensible
  out-of-the-box state. The permanent reference point.
- **User layer** — overrides only. Stored in `~/.config/pillbox/pillbox.conf`. Only keys
  the user has explicitly changed are persisted — not a full copy of defaults.

Resolved value = user override if one exists, otherwise the default. Fields that differ
from the default are visually distinguished in the panel (subtle accent tint). **Reset to
defaults** clears all user-layer keys; the defaults object is never touched.

---

## Services tab ✓

**File:** `module-panels/SettingsPanel.qml` (first section)

### Google Account

Calendar and Tasks share one OAuth token — connected or disconnected as a unit.

*Connected state:*
```
Google Account   ● rauf@gmail.com                [Re-authenticate]  [Disconnect]
  └ Calendar       last fetched 14:32
  └ Tasks          last fetched 14:31
```

- Account email read from the token file.
- Per-service last-fetch timestamps from `CalendarProcess.lastUpdated` / `TasksProcess.lastUpdated`.
- Per-service error state (`CalendarProcess.lastError` / `TasksProcess.lastError`): `""` (ok),
  `"auth"` (empty stdout + exit 1), `"network"` (non-empty stdout + exit 1).
- **Re-authenticate** — calls `google-auth-notify.sh` → opens terminal running `gcal-fetch --auth`.
- **Disconnect** — runs `gcal-fetch --revoke` (server-side revocation + local token delete),
  clears `/tmp/pillbox-google.log`, calls `settingsProcess.disconnect()`. Both processes respond
  with `clearData()` — no personal data lingers.

*Not connected state:*
```
Google Account   ○ Not connected                 [Connect]
  └ Calendar       —
  └ Tasks          —
```

- **Connect** — same flow as Re-authenticate.
- Processes skip fetch cycles while `googleConnected = false`.

### Weather location

`Auto` (IP geolocation via ipapi.co) or `Manual`. Manual accepts a city name or `lat,lon` pair,
passed to `weather-fetch --location`. An immediate re-fetch fires when the location changes.

### Data layer built for Services

- `SettingsProcess.qml` ✓ — `QtCore.Settings` singleton, `location` →
  `~/.config/pillbox/pillbox.conf`. Properties: `googleConnected`, `locationMode`, `locationString`.
  Methods: `disconnect()`, `reconnect()`, setters. Signal: `googleDisconnected`.
- `CalendarProcess` + `TasksProcess` ✓ — `lastError`, `clearData()`, fetch guard, disconnect listener.
- `gcal_fetch.py` ✓ — `--revoke` flag (urllib POST to oauth2.googleapis.com/revoke + delete token file).
- `WeatherProcess` ✓ — dynamic `command` binding; re-fetches on location change.
- `weather_fetch.py` ✓ — `--location` flag (Open-Meteo geocoding for city names; `lat,lon` parsed directly).

---

## Appearance tab — spec

### Tab bar

`SettingsPanel` gains a two-position `TogglePair` at the top:

```
[ Services ]  [ Appearance ]
```

Internal state: `property string _tab: "services"` (or `"appearance"`). The TogglePair drives it.
Services content and Appearance content are rendered as two separate `ColumnLayout` children with
`visible: root._tab === "..."`. No routing change needed in `PanelController` — it still just
opens `"settings"`.

---

### Controls (v1) — what Prefs.qml already exposes

All 7 Prefs properties get a control. Changes apply **live** — no staged draft, no Save needed.
The `Prefs.set*()` setters write directly to `pillbox.conf`; Style re-derives on the same frame.
Only a **Reset to defaults** button is needed (calls every setter with the default value).

#### Typography section

```
Pill text size    [ – ]  13  [ + ]      range 10–18 · Prefs.fontSizePill
Panel text size   [ – ]  10  [ + ]      range  8–14 · Prefs.fontSizeBase
Mono font         [ JetBrainsMono Nerd Font          ]   · Prefs.fontMono   (apply on Enter/blur)
Glyph font        [ JetBrainsMono Nerd Font          ]   · Prefs.fontNerd   (apply on Enter/blur)
```

Controls:
- **Stepper** — `RowLayout` with two `PanelButton` items (`label: "–"` / `label: "+"`) flanking
  a `Text` showing the current value. The `-` button is disabled at the lower bound, `+` at the
  upper bound (implemented by `variant: root._at_min ? "default" : "default"` + guard in
  `onClicked`). No new reusable component needed — inline in the Appearance section.
- **Font text input** — same `Rectangle + TextInput + placeholder Text` pattern used in the
  Weather Location card. `onAccepted` and `onEditingFinished` both call the Prefs setter.

#### Corner rounding section

```
Corner rounding   [ None ]  [ Subtle ]  [ ● Default ]
                    0.0        0.5          1.0
```

Control: three `PanelButton` items in a `RowLayout` with `Layout.fillWidth: true` on each. The
active choice uses `variant: "accent"`; the others use `variant: "default"`. A local property
`_radiusChoice` mirrors `Prefs.radiusScale` (`0` = none, `1` = subtle, `2` = default) and drives
the variant. Tapping calls `Prefs.setRadiusScale(value)`.

#### Borders section

Two rows, same three-way layout:

```
Container border  [ Off ]  [ ● Thin ]  [ Thick ]     · Prefs.borderWidth        (0 / 1 / 2)
Element border    [ Off ]  [ ● Thin ]  [ Thick ]     · Prefs.elementBorderWidth (0 / 1 / 2)
```

Same pattern as corner rounding — three `PanelButton` items, active one = `variant: "accent"`.

#### Reset

```
[ Reset to defaults ]    critical variant · calls all Prefs set*() with their default values
```

A single `PanelButton { variant: "critical"; label: "Reset to defaults" }` at the bottom.

---

### Layout structure

```qml
// inside SettingsPanel's outer ColumnLayout (_col):

TogglePair {
    labelA: "Services"
    labelB: "Appearance"
    selected: root._tab === "appearance" ? 1 : 0
    onToggled: (i) => root._tab = (i === 0 ? "services" : "appearance")
}

// ── Services content ──────────────────────────────────────────────────
ColumnLayout {
    visible: root._tab === "services"
    Layout.fillWidth: true
    // ... Google Account + Divider + Weather Location (existing)
}

// ── Appearance content ────────────────────────────────────────────────
ColumnLayout {
    visible: root._tab === "appearance"
    Layout.fillWidth: true
    spacing: 12

    Text { text: "Typography"; ... }
    PanelCard {
        ColumnLayout {
            // font size steppers + font text inputs
        }
    }

    Text { text: "Corner rounding"; ... }
    PanelCard {
        RowLayout { PanelButton×3 }
    }

    Text { text: "Borders"; ... }
    PanelCard {
        ColumnLayout {
            RowLayout { Text "Container"; PanelButton×3 }
            RowLayout { Text "Elements";  PanelButton×3 }
        }
    }

    PanelButton { label: "Reset to defaults"; variant: "critical" }
}
```

---

### v2 (deferred)

- **Palette** — 16 color swatches (`color0`–`color15`), inline hex `TextInput` per swatch.
  Requires adding `color0`–`color15` override properties to `Prefs.qml` and fallback logic in
  `Style.qml` (`color0: Prefs.color0Override || "#2E3440"`).
- **Timing constants** — calendar warning threshold, MPRIS peek duration, workspace flash duration.
  Requires wiring `CalendarProcess`, `MprisPill`, `WorkspacePill` to Prefs values.

---

## Architecture: how user overrides reach components ✓

### The pragma Singleton constraint

`Style.qml` is `pragma Singleton`. The QML engine instantiates it once when the module is first
imported — not by `shell.qml`, not by any component. This means `Style.qml` cannot "see" the
`settings` object that lives in `shell.qml`.

### Prefs.qml — the persistence singleton ✓

A dedicated **`Prefs.qml`** singleton owns all persistence. Two-singleton architecture:

```
quickshell/
├── Prefs.qml   ← pragma Singleton; owns QtCore.Settings block; exposes user-adjustable prefs
├── Style.qml   ← reads Prefs for derived tokens; owns all visual/token logic
└── shell.qml
```

**v1 Prefs properties** (font, radius, borders — live in `pillbox.conf`):

| Property | Default | Setter |
|---|---|---|
| `fontMono` | `"JetBrainsMono Nerd Font"` | `setFontMono(v)` |
| `fontNerd` | `"JetBrainsMono Nerd Font"` | `setFontNerd(v)` |
| `fontSizePill` | `13` | `setFontSizePill(v)` |
| `fontSizeBase` | `10` | `setFontSizeBase(v)` |
| `radiusScale` | `1.0` | `setRadiusScale(v)` |
| `borderWidth` | `1` | `setBorderWidth(v)` |
| `elementBorderWidth` | `1` | `setElementBorderWidth(v)` |

`Style.qml` derives `fontSizePill/Body/Heading/Subtle`, `radSm/Md/Lg`, `borderWidth`,
`elementBorderWidth` from these. Changes apply live — no restart needed.

**v2 (deferred):**
- Color palette overrides (`color0Override`–`color15Override`) — requires `Style.color0: Prefs.color0Override || "#2E3440"` fallback chain
- Timing constants (`calendarWarningMins`, MPRIS peek duration, workspace flash duration)

### Principles agreed so far

1. Every token in the Fixed section must be used by at least two unrelated components.
2. Token names describe *role*, not *visual outcome*: `textSubtle` not `textGray`.
3. One-off values stay inside the component that owns them.
4. The Variable section (`color0`–`color15`) is the only user-adjustable layer. The Fixed section
   is always derived — users change the palette, semantic tokens follow automatically.

### Token audit

Tables are built component-group by component-group. Each table lists every visual property in
that group, its current state, where it's used, and the action to take. Panels and shared
typography come after Pills.

Column key — **State**: ✓ token exists in Style · ✗ hardcoded magic number · ✗✗ token defined
in Style but never actually referenced (dead).

---

#### Pill

The pill system is `PillWindow` (the container) plus four content components: `TimePill`,
`MprisPill`, `WorkspacePill`, `WindowPill`.

Text colors, state colors, borders, and radius are not listed here — they live in the shared
tables below. Note: `criticalBgColor` is a candidate for the pill's urgent visual state
(`TimePill._calendarImminent`) once that state gets a visual treatment.

**Colors**

| Token | State | Palette source | Used by | Action |
|---|---|---|---|---|
| `pillBgColor` | ✓ | `color0` | PillWindow | Keep as-is |

**Dimensions**

| Token | State | Current value | Used by | Action |
|---|---|---|---|---|
| `pillHeight` | ✗ hardcoded | `24` | PillWindow | Add to Style |
| `pillPaddingH` | ✗ hardcoded | `20` per side | PillWindow | Add to Style |
| `pillTextMaxWidth` | ✗ hardcoded | `200` | MprisPill, WindowPill | Shared by 2 — add to Style |

**Spacing**

| Token | State | Value | Used by | Action |
|---|---|---|---|---|
| `pillContentSpacing` | ✗ hardcoded | `6` | MprisPill, WindowPill | Shared by 2 — add to Style |
| *(name ↔ dot cluster)* | ✗ hardcoded | `8` | WorkspacePill only | Keep inline — single component |
| *(dot ↔ dot)* | ✗ hardcoded | `2` | WorkspacePill only | Keep inline — single component |

---

#### Panel

Three panels: `CalendarPanel`, `WindowSwitcherPanel`, `SettingsPanel`.
Text colors, state colors, borders, and radius are not listed here — they live in the shared tables below.

**Colors**

| Token | State | Palette source | Used by | Action |
|---|---|---|---|---|
| `panelBgColor` | ✓ | `color0` | CalendarPanel, WindowSwitcherPanel | Keep — intentionally same value as `pillBgColor`; kept as separate tokens so they can diverge independently |
| `panelDividerColor` | ✓ | `color2` | CalendarPanel, SettingsPanel | Keep |
| `surfaceLowColor` | ✓ | `color1` | WindowSwitcherPanel (hover row), SettingsPanel (section cards) | Keep |
| `surfaceMidColor` | ✓ | `color2` | All 3 panels — buttons, filter bar, text inputs | Keep |
| `accentColor` | ✗✗ named `borderAccentColor` | `color10` | CalendarPanel — today cell bg + accent text (back button, nav arrows) | Rename: `borderAccentColor` is misleading; used as both background and text accent |

**Dimensions**

| Token | State | Current value | Used by | Action |
|---|---|---|---|---|
| `panelMargin` | ✗ hardcoded | `12` | CalendarPanel, SettingsPanel | Add to Style |
| `buttonHeight` | ✗ hardcoded | `22` | All 3 panels | Add to Style |

---

#### Text colors — shared across Pill and Panel

Text tokens are separated from the Pill/Panel tables because they are used by both.
Dark mode only — no light/dark switching is planned.

**Hierarchy (contrast against dark background, high → low)**

| Token | Color | Hex | Example use |
|---|---|---|---|
| `textPrimary` | `color6` | `#ECEFF4` | Pill text, panel headings |
| `textNormal` | `color5` | `#E5E9F0` | Standard body copy |
| `textSecondary` | `color4` | `#D8DEE9` | Button labels, secondary info |
| `textMuted` | `color3` | `#4C566A` | Timestamps, section labels, text on accent background (e.g. calendar "today" cell, window switcher selected item) |
| `textFaint` | `color2` | `#434C5E` | Structural anchors, barely-visible elements |

**Semantic (outside the brightness scale)**

| Token | Color | Hex | Example use |
|---|---|---|---|
| `textAccent` | `color9` | `#81A1C1` | Interactive / branded text |
| `textCritical` | `color11` | `#BF616A` | Error / alert state |
| `textSuccess` | `color14` | `#A3BE8C` | Positive / completion state |

> **Style.qml cleanup required:**
> - `textLight`, `textMuted`, `textButton` all currently map to `color4` — collapse to `textSecondary`.
> - `textSubtle`, `textDim` both map to `color3` — collapse to `textMuted`.
> - **`textMuted` changes value**: current `textMuted` = `color4`; new `textMuted` = `color3`. Any component using `textMuted` today will render slightly dimmer after the refactor — intentional.
> - `textAccentColor` (current name in Style) → rename to `textAccent`.
> - `textWeekend` (`color10`) and `dotIndicator` (`color8`) — used only in CalendarPanel; remove from Style and move inline.

---

#### State colors — shared across Pill and Panel

State colors are background tints for interactive and feedback states. All are derived from
palette colors in Style's Fixed section — never standalone entries in Prefs. When the user
changes a palette color, its derived state tint updates automatically.

| Token | State | Derivation | Example use |
|---|---|---|---|
| `accentBgColor` | ✓ exists | `Qt.darker(color10, 2.4)` | Selected row (WindowSwitcherPanel), active toggle (SettingsPanel) |
| `accentBgHover` | ✓ exists, unused | `Qt.darker(color10, 1.8)` | Hover on accent interactive elements — will be used by `PanelButton` reusable component |
| `criticalBgColor` | ✗ add to Style | `Qt.darker(color11, 2.4)` | Error state tint — auth failure, input validation error, pill urgent state |
| `successBgColor` | ✗ add to Style | `Qt.darker(color14, 2.4)` | Positive state tint — save confirmation, timer completion |

---

#### Border — shared across Pill and Panel

Like radius, one setting drives all border widths simultaneously. Border colors are
palette-derived in Style's Fixed section — no user preference needed for color.

**Width (Prefs — user adjustable)**

Pill and panel share the same setting and default. Inner elements (buttons, inputs) have
their own setting so a borderless container doesn't force borderless buttons.

| Token | Default | Controls |
|---|---|---|
| `borderWidth` | `1` | Pill container, panel container |
| `elementBorderWidth` | `1` | Buttons, inputs, filter bar within panels |

**Color (Style Fixed — palette-derived, not in Prefs)**

| Token | State | Source | Used by | Note |
|---|---|---|---|---|
| `borderFaintColor` | ✓ exists | `color1` | Pill, panel container | Very subtle — barely distinguishable from the container bg; just defines the edge |
| `borderSoftColor` | ✓ exists | `color3` | Buttons, inputs, filter bar | Slightly more visible — helps small interactive elements read as distinct shapes |

---

#### Radius — shared across Pill and Panel

Corner radius is not a per-component value — it is a single user preference that scales
the entire UI simultaneously. When a user sets "no rounding", everything goes sharp at once.

**How it works:**

`Prefs.qml` holds one property:

```qml
property real radiusScale: 1.0   // 0.0 = sharp  ·  0.5 = subtle  ·  1.0 = default
```

`Style.qml` derives all three radius tokens from it:

```qml
readonly property real radSm: Math.round(4  * Prefs.radiusScale)
readonly property real radMd: Math.round(6  * Prefs.radiusScale)
readonly property real radLg: Math.round(10 * Prefs.radiusScale)
```

Components reference the scale tokens directly — no semantic aliases like `pillBorderRadius`
or `panelBorderRadius` needed. Both currently use `radLg`; if they ever need to diverge we
add a named alias at that point.

**Radius scale**

| Token | Base value | scale=0 | scale=0.5 | scale=1 (default) | Used by |
|---|---|---|---|---|---|
| `radSm` | 4 | 0 | 2 | 4 | Buttons, small elements |
| `radMd` | 6 | 0 | 3 | 6 | Mid-size elements (inline) |
| `radLg` | 10 | 0 | 5 | 10 | Pill container, panel container |

**Appearance tab UI:**

A single discrete selector — not three separate sliders:

```
Corner rounding    [None]  [Subtle]  [● Default]
                    0.0      0.5        1.0
```

**Variable section renames:**
- `radLight` → `radSm`
- `radHigh` → `radLg`
- `radMed` — name unchanged
- `radNone` — keep as constant `0` (not scaled)

**Fixed section tokens to remove:**
`pillBorderRadius`, `panelBorderRadius`, `radButton`, `radButtonSmall`, `radGridToday`,
`radGridTooltip` — replaced by direct `radSm` / `radMd` / `radLg` references.

**Border primitives to remove:**
`borderNone`, `borderThin`, `borderThick` — replaced by `Prefs.borderWidth` and
`Prefs.elementBorderWidth` read via `Style`.

---

#### Typography — shared across Pill and Panel

**Font families**

| Token | Where | Default | Note |
|---|---|---|---|
| `fontMono` | Prefs | JetBrainsMono Nerd Font | All text content — must be monospace |
| `fontNerd` | Prefs | JetBrainsMono Nerd Font | Icon glyphs — must be a Nerd Font; no enforcement possible at QML level |
| `fontCJK` | Style constant | Sarasa Mono SC | Reserved for CJK content — not user-adjustable in v1 |

> `fontMono` and `fontNerd` will usually be the same family in practice. Kept separate
> because their roles differ and may diverge if the user chooses different fonts for text
> vs. glyphs.

**Font sizes**

Two Prefs entries drive the scale. Style derives semantic aliases from them.

*Prefs (user-adjustable):*

| Token | Default | Controls |
|---|---|---|
| `fontSizePill` | `13` | Pill text — independent; pill is a distinct visual zone from panels |
| `fontSizeBase` | `10` | Anchor for the panel text scale |

*Style Fixed (derived from `fontSizeBase`):*

| Token | Derivation | Default | Used by |
|---|---|---|---|
| `fontSizeHeading` | `fontSizeBase + 2` | `12` | Panel section headers — CalendarPanel, SettingsPanel |
| `fontSizeBody` | `fontSizeBase` | `10` | Standard panel content — all 3 panels |
| `fontSizeSubtle` | `fontSizeBase - 1` | `9` | Smallest panel text — grid numbers, section labels |

**Single-use size tokens — remove from Style, move inline:**

| Current token | Value | Lives in | Action |
|---|---|---|---|
| `fontTimerSize` | `22` | TimerWidget only | Inline constant in TimerWidget |
| `fontNavSize` | `11` | CalendarPanel only | Inline constant in CalendarPanel |
| `fontGridNumSize` | `9` | CalendarPanel only | Replace with `Style.fontSizeSubtle` |
| `fontLabelSize` | `8` | CalendarPanel only | Inline constant in CalendarPanel |
| `fontWeatherIcon` | `13` | CalendarPanel only | Inline constant in CalendarPanel |

**Variable section size scale — remove from Style entirely:**

`sizeXl`, `sizeLg`, `sizeMd`, `sizeSm`, `sizeXs`, `sizeXxs`, `sizeLabel` — raw numeric
primitives replaced by the semantic tokens above. Components reference `Style.fontSizeBody`
etc., not raw sizes.

**Appearance tab UI:**

```
Pill text size    [slider 10–18]   default 13
Panel text size   [slider  8–14]   default 10
Mono font         [text input]     default "JetBrainsMono Nerd Font"
Glyph font        [text input]     default "JetBrainsMono Nerd Font"
```

---

## Build order

1. ✓ **Audit** all panels and pills — token tables complete. Style.qml cleanup list identified.
2. ✓ **Add** `Prefs.qml` singleton — persists font, radius, border prefs to `pillbox.conf`.
3. ✓ **Extend** `Style.qml` — Prefs-derived Fixed section (`fontSizeBody`, `radSm`/`Md`/`Lg`,
   `borderWidth`, `elementBorderWidth`, etc.). Old aliases kept for backward compat.
4. ✓ **Create** reusable elements — `PanelButton`, `SectionLabel`, `PanelDivider`, `TogglePair`,
   `StatusDot`, `PanelCard`.
5. ✓ **Refactor** `SettingsPanel`, `CalendarPanel`, `WindowSwitcherPanel` — components wired,
   new token names used throughout.
6. → **Clean up** `Style.qml` — fix `PillWindow.pillBorderRadius → radLg`, then remove all
   backward-compat aliases (`fontContentSize`, `fontHeaderSize`, `radButton`, `radLight`,
   `radHigh`, `panelBorderRadius`, `textLight`, `textButton`, `textSubtle`, `textDim`,
   `borderNone/Thin/Thick`, etc.).
7. → **Build** Appearance tab — tab bar (`TogglePair`), Typography card (stepper + text inputs),
   Corner rounding card (3-way selector), Borders card (3-way × 2), Reset button. Spec: see above.
8. (v2) **Wire** timing constants (`CalendarProcess`, `MprisPill`, `WorkspacePill`) through Prefs.
9. (v2) **Build** Palette section — 16 color swatches + hex inputs; extend `Prefs.qml`.

---

## Open questions

- **Palette UX** (v2) — pure hex `TextInput` per swatch, or a `ColorDialog`? Hex-only is
  lightweight and consistent with the existing TextInput style; ColorDialog is richer but heavier.

- **Timing constants** (v2) — separate "Tuning" tab, or folded into a third SettingsPanel tab?
