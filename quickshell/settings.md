# Settings Panel — Design Notes

This file is the living design document for the Settings panel. All decisions, rationale,
and open questions live here. The README carries only a pointer.

---

## Status

| Area | State |
|---|---|
| Services tab | ✓ built and wired |
| Design system audit | in progress — discussing |
| Reusable elements | not started |
| Appearance tab | design phase |

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

## Appearance tab — design phase

### What users will be able to change

1. **Palette** — 16 color swatches (`color0`–`color15`). Clicking a swatch opens an inline hex
   input. Changes update the UI live. Stored as overrides in `pillbox.conf`; unedited slots fall
   back to the compiled Nord defaults.

2. **Timing constants** — three sliders with live value labels:
   - Calendar warning threshold — minutes before an event the pill enters urgency state. Default 10, range 1–60.
   - MPRIS peek duration — seconds the pill stays visible after a track/state change. Default 3, range 1–10.
   - Workspace flash duration — seconds the workspace pill stays visible after a switch. Default 1.5, range 0.5–5.

3. **Save / Reset** — Save writes all staged changes to the user layer; Reset clears all user-layer
   keys and restores compiled defaults.

---

## Architecture: how user overrides reach components

### The pragma Singleton constraint

`Style.qml` is `pragma Singleton`. The QML engine instantiates it once when the module is first
imported — not by `shell.qml`, not by any component. Because instantiation is out of our hands,
we can never inject a property into it:

```qml
// impossible — singletons are not instantiated by the caller
Style { settingsProcess: settings }
```

This means `Style.qml` cannot "see" the `settings` object that lives in `shell.qml`. The two
live in completely separate parts of the object tree.

### Prefs.qml — the persistence singleton

Instead of duplicating a `Settings {}` block inside `Style.qml` (two QSettings instances on the
same file, mixed concerns), we introduce a dedicated **`Prefs.qml`** singleton:

```
quickshell/
├── Prefs.qml      ← pragma Singleton; owns Settings{} block; exposes color + timing overrides
├── Style.qml      ← reads Prefs for override values; keeps all visual/token logic
└── shell.qml
```

- **`Prefs.qml`** is the only file that touches `QtCore.Settings`. It exposes properties like
  `color0Override: ""` (empty string = no override) and timing properties with numeric defaults.
  It also provides setters (`function setColor(index, hex)`). Declared as a singleton in the root
  `qmldir` so any QML file in the project can import it.

- **`Style.qml`** reads Prefs for the variable section:
  ```qml
  readonly property color color0: Prefs.color0Override || "#2E3440"
  ```
  The compiled hex is the fallback; an empty override is falsy and falls through. No persistence
  logic in Style — it stays purely visual.

- **`SettingsProcess.qml`** delegates color/timing writes to Prefs:
  ```qml
  function setPaletteColor(index, hex) { Prefs.setColor(index, hex) }
  ```
  It continues to own `googleConnected`, `locationMode`, `locationString` directly (these are
  behavioural, not visual, and don't need to be in Prefs).

- **Timing constants** — `CalendarProcess`, `MprisPill`, `WorkspacePill` read from Prefs:
  ```qml
  property int warningThresholdMins: Prefs.calendarWarningMins  // default 10
  ```

---

## Design system work — prerequisite for Appearance tab

Before building the Appearance UI, we need the design system underneath it to be coherent.
Currently `Style.qml` and the panel components have two problems:

### Problem 1: Style.qml Fixed section conflates two categories

The Fixed (semantic) section currently mixes:

- **Genuine shared tokens** — values that are meaningfully used by multiple unrelated components.
  These belong in Style. Examples: `textPrimary`, `panelBgColor`, `accentBgColor`, `surfaceLowColor`.

- **One-off implementation details** — values that only exist because one component needed a magic
  number, then got promoted to a token. These should live inside the component that owns them.
  Examples in the current file: `radGridToday`, `radGridTooltip`, `fontTimerSize`.

Goal: every token in the Fixed section is genuinely shared and semantically meaningful. A new
component can build itself from existing tokens without adding anything to Style.

### Problem 2: repeated layout boilerplate in panels

The same visual patterns appear across CalendarPanel, SettingsPanel, and WindowSwitcherPanel with
duplicated markup. This makes changes require touching multiple files and makes the Appearance tab
harder to reason about (the style is scattered).

### Candidate reusable elements

The following patterns recur across panels and are worth extracting into `module-reusable-elements/`:

| Component | Pattern | Currently appears in |
|---|---|---|
| `PanelButton.qml` | Rectangle + hover state + border + label text | CalendarPanel ×3, SettingsPanel ×4 |
| `SectionLabel.qml` | All-caps tracking label (EVENTS TODAY, etc.) | CalendarPanel ×4, SettingsPanel ×2 |
| `PanelDivider.qml` | Full-width 1px horizontal rule | CalendarPanel ×2, SettingsPanel ×1 |
| `TogglePair.qml` | Two-button exclusive toggle (Auto/Manual style) | SettingsPanel ×1, Appearance tab later |
| `StatusDot.qml` | Filled/hollow dot with configurable color | SettingsPanel ×1 |

Each component encapsulates hover behaviour, sizing, and Style token references internally.
Callers provide only the semantic inputs (`text:`, `onClicked:`, `active:`, etc.).

### What a clean PanelButton looks like

Before (current CalendarPanel footer):
```qml
Rectangle {
    Layout.fillWidth: true
    height: 22; radius: Style.radButton
    color: moreHover.containsMouse ? Style.surfaceMidColor : Style.surfaceLowColor
    border.color: Style.borderSoftColor; border.width: 1
    Text { anchors.centerIn: parent; text: "More ↓"; color: Style.textButton; font.pixelSize: Style.fontContentSize }
    MouseArea { id: moreHover; anchors.fill: parent; hoverEnabled: true; onClicked: root._view = "expanded" }
}
```

After:
```qml
PanelButton { text: "More ↓"; onClicked: root._view = "expanded" }
```

The same improvement applies to `SectionLabel` and `PanelDivider` — each eliminates ~4 lines of
repeated boilerplate at every call site.

---

## Style.qml redesign — discussion

This section is where we work out what the Fixed section should look like. Work in progress.

### Principles agreed so far

1. Every token in the Fixed section must be used by at least two unrelated components.
2. Token names describe *role*, not *visual outcome*: `textSubtle` not `textGray`.
3. One-off values stay inside the component that owns them.
4. The Variable section (`color0`–`color15`) is the only user-adjustable layer. The Fixed section
   is always derived — users change the palette, semantic tokens follow automatically.

### Tokens that look like genuine candidates (to audit)

From the current Fixed section, the following feel like real shared tokens worth keeping:

**Surfaces:**
- `panelBgColor`, `panelBorderColor`, `panelDividerColor`, `panelBorderRadius`
- `surfaceLowColor`, `surfaceMidColor`
- `borderSoftColor`, `borderFaintColor`

**Accent / interactive:**
- `accentBgColor`, `accentBgHover`, `borderAccentColor`, `textAccentColor`

**Typography roles:**
- `textPrimary`, `textNormal`, `textLight`, `textMuted`, `textSubtle`, `textDim`, `textFaint`
- `textCritical`, `textSuccess`
- `textButton`, `textWeekend`, `dotIndicator`

**Radii:**
- `radButton` — shared across all buttons
- `radNone`, `radLight`, `radMed`, `radHigh` — the scale primitives (keep in Variable section)

**Tokens to audit / possibly remove:**
- `radGridToday`, `radGridTooltip` — only used in CalendarPanel; belong inside it
- `fontTimerSize` — only used in TimerWidget; belongs inside it
- `tooltipBorder`, `tooltipTextSoft` — check if reused; may belong in a shared Tooltip component

### Typography scale

Font sizes (`sizeXl` down to `sizeLabel`) are Variable-section primitives. The semantic aliases
(`fontHeaderSize`, `fontContentSize`, etc.) in Fixed are worth keeping — they give names to roles
rather than point sizes, and multiple components use them.

Font families (`fontMono`, `fontNerd`, `fontCJK`) should eventually be user-adjustable via Prefs,
but that is out of scope for the first Appearance tab.

---

## Build order (once design discussion is complete)

1. **Audit** all panels and pills — confirm which Style tokens are actually shared, and which
   patterns recur. (CalendarPanel read; others still to check.)
2. **Finalize** the Fixed section token set in this document.
3. **Create** reusable elements: `PanelButton`, `SectionLabel`, `PanelDivider`, `TogglePair`, `StatusDot`.
4. **Refactor** existing panels (CalendarPanel, SettingsPanel, WindowSwitcherPanel) to use them.
   Remove one-off tokens from Style.qml Fixed section.
5. **Add** `Prefs.qml` singleton + wire `Style.qml` color primitives through it.
6. **Wire** timing constants: `CalendarProcess`, `MprisPill`, `WorkspacePill` read from Prefs.
7. **Build** Appearance tab: tab bar, palette swatches, timing sliders, Save / Reset.
8. **Refactor** `SettingsPanel.qml` to use the new reusable elements throughout.

---

## Open questions

- **Palette UX** — pure hex `TextInput` per swatch, or a `ColorDialog`? Hex-only is lightweight
  and consistent with the existing TextInput style; ColorDialog is richer but heavier.

- **Save vs. live preview** — the spec says staged until Save. Given palette and timing changes
  are cheap to apply immediately, is live-preview-on-type (no Save, just Reset) more appealing?

- **Tab bar style** — same pill-style toggle as the Auto/Manual weather pair, or a different
  treatment (e.g. underline indicator)?

- **Style.qml Fixed audit** — need to read WindowSwitcherPanel, all pills, and SettingsPanel
  in full to confirm which tokens are genuinely shared vs. candidates for removal.
