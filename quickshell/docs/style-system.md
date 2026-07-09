# Style System

How visual tokens, user preferences, and the color palette are organized in Pillbox.

---

## Status — POC, Wired Last

> **The current Style.qml and Prefs.qml are a working proof-of-concept sufficient to build and test all panels and pills. They are intentionally not the final implementation.**
>
> The full style system is designed to be wired last — after all panels and pills are feature-complete and tested. At that point: token tables are finalized, all fix candidates below are resolved, the palette section is built out in Prefs, and Style.qml is cleaned up. Until then, POC tokens remain in place so development is not blocked.
>
> Fix candidates in this document mark where the current code deviates from the intended design.

---

## Architecture

```
Prefs.qml  (pragma Singleton)
    └── QtCore.Settings → ~/.config/pillbox/pillbox.conf
    └── Exposes readonly aliases + set*() functions
            ↓
Style.qml  (pragma Singleton)
    └── Variable section  — raw 16-color palette (color0–color15)
    └── Fixed section     — semantic mappings (textPrimary, accentBgColor, …)
    └── Prefs-derived     — live-updating tokens (fontSizeBody, radSm, …)
            ↓
All components — read Style.* only, never Variable or Prefs directly
```

**Two-singleton design:** `Style.qml` is instantiated by the QML engine, not by `shell.qml`, so it cannot reach runtime objects. `Prefs.qml` is a second singleton that owns `QtCore.Settings`. `Style.qml` reads `Prefs.*` for derived tokens. Any change in Prefs propagates through Style to every component on the same frame — live, no restart.

---

## Two-Layer Preference Model

All settings operate on two layers:

- **Defaults** — compiled-in baseline. Never written to disk. The permanent reference point.
- **User layer** — overrides only. Stored in `~/.config/pillbox/pillbox.conf`. Only keys the user has explicitly changed are persisted.

Resolved value = user override if present, otherwise the compiled default. `QtCore.Settings` handles this automatically.

> **Fix candidate:** Modified fields (values that differ from their compiled default) should be visually distinguished in the Settings → Appearance UI with a subtle accent tint. Not yet implemented.

> **Fix candidate (deferred):** User preference changes do not currently persist across quickshell restarts. The intention is that any value written via a `Prefs.set*()` call survives a quickshell reload and is restored on next launch. `QtCore.Settings` is the intended mechanism — the fix is to ensure it is wired and flushed correctly before the process exits.

---

## Prefs.qml

**File:** `Prefs.qml` (root, `pragma Singleton`)
**Persists to:** `~/.config/pillbox/pillbox.conf`

### Appearance properties

| Property | Type | Default | Setter | Controls |
|---|---|---|---|---|
| `fontMono` | `string` | `"JetBrainsMono Nerd Font"` | `setFontMono(v)` | All text content |
| `fontNerd` | `string` | `"JetBrainsMono Nerd Font"` | `setFontNerd(v)` | Nerd Font glyphs |
| `fontSizePill` | `int` | `13` | `setFontSizePill(v)` | Pill text — independent of panel scale |
| `fontSizeBase` | `int` | `10` | `setFontSizeBase(v)` | Panel text scale anchor |
| `radiusScale` | `real` | `1.0` | `setRadiusScale(v)` | 0.0 = sharp · 0.5 = subtle · 1.0 = default |
| `borderWidth` | `int` | `1` | `setBorderWidth(v)` | Pill + panel container borders (0 / 1 / 2) |
| `elementBorderWidth` | `int` | `1` | `setElementBorderWidth(v)` | Buttons, inputs within panels (0 / 1 / 2) |

These are two separate settings so a user who wants a borderless pill/panel container isn't forced into borderless buttons too — container chrome and interactive-element chrome scale independently.

### Wallpaper properties

| Property | Type | Default | Setter |
|---|---|---|---|
| `wallpaperSourceType` | `string` | `"color"` | `setWallpaperSourceType(v)` |
| `wallpaperPath` | `string` | `""` | `setWallpaperPath(v)` |
| `wallpaperColor` | `string` | `"#2E3440"` | `setWallpaperColor(v)` |
| `wallpaperDir` | `string` | `""` | `setWallpaperDir(v)` |
| `slideshowInterval` | `int` | `60` | `setSlideshowInterval(v)` |

### v2 — Palette overrides (deferred)

Per-slot palette overrides so users can customise individual colors without replacing the whole theme. Style falls back to the Nord default when a slot is unset.

```qml
// In Prefs._store:
property string color0Override: ""
// ... color1Override–color15Override

// In Style.qml Variable section:
readonly property color color0: Prefs.color0Override || "#2E3440"
// ... color1–color15 same pattern
```

This is also the integration point for wallpaper color extraction (pywal / matugen output format matches the 16-slot terminal palette exactly).

### v2 — Timing constants (deferred)

| Property | Intent |
|---|---|
| `calendarWarningMins` | How far ahead an event triggers TimePill urgent state (currently hardcoded `10`) |
| `mprisPeekMs` | How long MprisPill stays visible after a track change (currently hardcoded `3000`) |
| `workspaceFlashMs` | How long WorkspacePill stays visible after a switch (currently hardcoded `1500`) |

**Open question:** Where do timing constants live in the Settings UI? Two options: (a) a dedicated "Tuning" tab in SettingsPanel alongside Services and Appearance, or (b) a separate hidden developer panel. Decision deferred until v2 scope is clearer.

---

## Style.qml

**File:** `Style.qml` (root, `pragma Singleton`)

Registered in the root `qmldir` and re-exported in each subdirectory's `qmldir` so all modules can reference `Style.*` without an explicit import path.

### Section 1 — Variable (palette)

The only layer intended to change when a theme is applied. Components never read these directly — they go through Fixed.

| Token | Hex (Nord default) | Role |
|---|---|---|
| `color0` | `#2E3440` | Deepest background |
| `color1` | `#3B4252` | Low surface, faint border |
| `color2` | `#434C5E` | Raised surface, button fill |
| `color3` | `#4C566A` | Dim border, inactive text |
| `color4` | `#D8DEE9` | Secondary text |
| `color5` | `#E5E9F0` | Standard body text |
| `color6` | `#ECEFF4` | Primary / heading text |
| `color7` | `#8FBCBB` | Frost teal — unassigned |
| `color8` | `#88C0D0` | Frost ice-blue — event dot indicators |
| `color9` | `#81A1C1` | Frost soft-blue — accent text |
| `color10` | `#5E81AC` | Frost deep-blue — accent bg, focus, borders |
| `color11` | `#BF616A` | Aurora red — critical / error |
| `color12` | `#D08770` | Aurora orange — unassigned |
| `color13` | `#EBCB8B` | Aurora yellow — unassigned |
| `color14` | `#A3BE8C` | Aurora green — success |
| `color15` | `#B48EAD` | Aurora purple — unassigned |

Also: `transparent: "transparent"`

Font tokens also live in Variable:
- `fontMono: Prefs.fontMono` — all text content; must be monospace
- `fontNerd: Prefs.fontNerd` — Nerd Font glyphs
- `fontCJK: "Sarasa Mono SC"` — CJK fallback; constant, not user-adjustable in v1

`fontMono` and `fontNerd` default to the same family (`JetBrainsMono Nerd Font`) and will often stay the same in practice. They are separate tokens because their roles differ and a user might want a different display font for text vs. a dedicated icon font for glyphs.

`fontCJK` exists because `font.families` (the Qt list-form fallback) is not available in this Qt build. Components use `font.family: Style.fontMono` (single family); Qt asks fontconfig for any missing glyphs and fontconfig resolves to Sarasa for CJK characters. `fontCJK` documents the intent — when `font.families` becomes available, it becomes the explicit fallback list instead of relying on fontconfig.

### Section 2 — Fixed (semantic tokens)

Semantic mappings over the Variable palette. Components always use these names, never `color0` etc. directly. When the palette changes, Fixed tokens update automatically.

#### Surfaces & Structure

| Token | Source | Role | Status |
|---|---|---|---|
| `pillBgColor` | `color0` | Pill window background | ✓ |
| `panelBgColor` | `color0` | Panel window background — separate token from `pillBgColor` so they can diverge | ✓ |
| `panelBorderColor` | `color1` | Panel outer border | ✓ |
| `panelDividerColor` | `color2` | `PanelDivider` horizontal rule | ✓ |
| `surfaceLowColor` | `color1` | Raised section bg (`PanelCard`), hover rows | ✓ |
| `surfaceMidColor` | `color2` | Buttons, text inputs, filter bar | ✓ |

#### Borders

| Token | Source | Role | Status |
|---|---|---|---|
| `borderFaintColor` | `color1` | Pill + panel container border — very subtle | ✓ |
| `borderSoftColor` | `color3` | Buttons, inputs — slightly more visible | ✓ |
| `borderAccentColor` | `color10` | Accent / focus border | ✓ — **fix candidate: redundant with `accentColor`; both = `color10`. Remove `borderAccentColor`, use `accentColor` everywhere.** |

#### Accent

| Token | Source | Role | Status |
|---|---|---|---|
| `accentBgColor` | `Qt.darker(color10, 2.4)` | Selected/active bg (TogglePair selected, window switcher selection) | ✓ |
| `accentBgHover` | `Qt.darker(color10, 1.8)` | Hover on accent interactive elements | ✓ |
| `accentColor` | `color10` | Accent text, active borders, today cell bg in calendar | ✓ |
| `criticalBgColor` | `Qt.darker(color11, 2.4)` | Error state tint | ✓ |
| `successBgColor` | `Qt.darker(color14, 2.4)` | Positive state tint | ✓ |

#### Text

The text hierarchy is ordered by contrast against the dark background (high → low), then semantic states.

| Token | Source | Role | Status |
|---|---|---|---|
| `textPrimary` | `color6` | Headings, pill text | ✓ |
| `textNormal` | `color5` | Standard body copy | ✓ |
| `textSecondary` | `color4` | Button labels, secondary info | ✓ |
| `textMuted` | `color4` | Timestamps, section labels, text on accent bg | ✓ POC — **fix candidate: must change to `color3`**. Current `textMuted` (`color4`) is the same value as `textSecondary`, making them indistinguishable. The intended value is `color3` (dimmer). Components using `textMuted` today will render slightly darker after the fix — intentional. |
| `textFaint` | `color2` | Barely-visible structural anchors | ✓ |
| `textAccent` | `color9` | Interactive / branded text | ✓ |
| `textCritical` | `color11` | Error / alert state | ✓ |
| `textSuccess` | `color14` | Positive / completion state | ✓ |
| `textWeekend` | `color10` | Calendar weekend day numbers | ✓ POC — **fix candidate: single-use token (CalendarPanel only). Move inline, remove from Style.** |
| `dotIndicator` | `color8` | Calendar event dot markers | ✓ POC — **fix candidate: single-use token (CalendarPanel only). Move inline, remove from Style.** |

#### Layout Constants

| Token | Value | Role | Status |
|---|---|---|---|
| `buttonHeight` | `22` | Fixed height for all `PanelButton` instances | ✓ |
| `panelMargin` | `12` | Standard inner margin for panel content | ✓ |

### Section 3 — Prefs-derived (live-updating)

Re-derive whenever the user changes a Prefs value. No restart required.

#### Typography

| Token | Derivation | Default | Role |
|---|---|---|---|
| `fontSizePill` | `Prefs.fontSizePill` | `13` | Pill text |
| `fontSizeHeading` | `Prefs.fontSizeBase + 2` | `12` | Panel section headers |
| `fontSizeBody` | `Prefs.fontSizeBase` | `10` | Standard panel content |
| `fontSizeSubtle` | `Prefs.fontSizeBase - 1` | `9` | Smallest panel text (timestamps, grid numbers) |

#### Radius

`Prefs.radiusScale` (0.0 / 0.5 / 1.0) scales all corners simultaneously. One preference, entire UI shifts at once.

| Token | Base | scale=0 | scale=0.5 | scale=1 | Used by |
|---|---|---|---|---|---|
| `radSm` | 4 | 0 | 2 | 4 | Buttons, small elements |
| `radMd` | 6 | 0 | 3 | 6 | Mid-size elements |
| `radLg` | 10 | 0 | 5 | 10 | Pill + panel containers |

#### Border Widths

| Token | Default | Role |
|---|---|---|
| `borderWidth` | `1` | Pill + panel container borders |
| `elementBorderWidth` | `1` | Buttons, inputs within panels |

---

## Pill Dimension Tokens (pending addition)

These values are currently hardcoded in their respective components. They should be in Style as named tokens because more than one component shares them.

| Intended token | Hardcoded value | Used by | Action |
|---|---|---|---|
| `pillHeight` | `24` | `PillWindow` | Add to Style Fixed |
| `pillPaddingH` | `20` (per side) | `PillWindow` | Add to Style Fixed |
| `pillTextMaxWidth` | `200` | `MprisPill`, `WindowPill` | Add to Style Fixed (shared by 2) |
| `pillContentSpacing` | `6` | `MprisPill`, `WindowPill` | Add to Style Fixed (shared by 2) |

WorkspacePill-only spacing (`8` between name and dot cluster, `2` between dots) stays inline — single component.

---

## Token Design Principles

1. Every token in the Fixed section must be used by at least two unrelated components. Single-use values belong inline in the component.
2. Token names describe *role*, not *visual outcome*: `textMuted` not `textGray`.
3. The Variable section (`color0`–`color15`) is the only user-adjustable layer. Fixed tokens always derive from it — users change the palette, semantic tokens follow automatically.
4. `fontMono` and `fontNerd` are kept as separate Prefs properties even though they default to the same font. Their roles differ and a user may want different fonts for text vs. glyphs.
5. Dark mode only — no light/dark switching planned. No `@media prefers-color-scheme` equivalent needed in QML.

---

## Open Fix Candidates (summary)

All items tagged above, collected here for easy tracking:

| # | What | Where | Fix |
|---|---|---|---|
| 1 | `textMuted` must change value | `Style.qml` Fixed | Change from `color4` to `color3`; audit all callsites — they'll render slightly dimmer |
| 2 | `borderAccentColor` redundant | `Style.qml` Fixed | Remove; replace callsites with `accentColor` |
| 3 | `textWeekend` single-use | `Style.qml` Fixed | Remove; move `color10` inline in CalendarPanel |
| 4 | `dotIndicator` single-use | `Style.qml` Fixed | Remove; move `color8` inline in CalendarPanel |
| 5 | Pill dimension tokens hardcoded | `PillWindow`, `MprisPill`, `WindowPill` | Add `pillHeight`, `pillPaddingH`, `pillTextMaxWidth`, `pillContentSpacing` to Style Fixed |
| 6 | Modified prefs fields have no accent tint | `SettingsPanel.qml` Appearance tab | Add subtle `accentBgColor` tint to fields whose value differs from the compiled default |
| 7 | Preference changes do not persist across restarts (deferred) | `Prefs.qml` / `QtCore.Settings` | Ensure `QtCore.Settings` is correctly wired and flushed so user values survive quickshell reload |

---

## v2 — Palette Section in Settings

Full 16-slot palette editor in Settings → Appearance, below the existing controls.

**UI sketch:**
```
Palette
  color0  [ #2E3440 ]  ████
  color1  [ #3B4252 ]  ████
  ...
  color15 [ #B48EAD ]  ████
  [ Reset palette ]
```

Each row: slot label · hex `TextInput` · color swatch preview `Rectangle`. On `onAccepted` / `onEditingFinished` → `Prefs.setColor0Override(v)`. Style derives `color0: Prefs.color0Override || "#2E3440"`.

`[ Reset palette ]` clears all override keys, restoring Nord defaults.

**Open question:** Pure hex `TextInput` per swatch, or a `ColorDialog`? Hex-only is lighter and consistent with the existing TextInput pattern. `ColorDialog` is richer but heavier. Decide when building.
