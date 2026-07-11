# Style System

How visual tokens, user preferences, and the color palette are organized in Pillbox.

---

## Status — Implemented

The mat3 color pipeline is fully implemented. `Style.qml` now derives all semantic tokens from Material Design 3 roles, which are populated by `matugen` on wallpaper change and persisted via `Prefs.qml`. Nord palette values serve as fallbacks when extraction is off or matugen is not installed.

Non-color concerns (typography scale, radius, border widths, layout constants) remain Prefs-driven as before. Pill dimension tokens (`pillHeight`, `pillPaddingH`, etc.) are the remaining hardcoded fix candidate — deferred to a future pass.

---

## Architecture

```
Prefs.qml  (pragma Singleton)
    └── QtCore.Settings → ~/.config/pillbox.conf
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
- **User layer** — overrides only. Stored in `~/.config/pillbox.conf`. Only keys the user has explicitly changed are persisted.

Resolved value = user override if present, otherwise the compiled default. `QtCore.Settings` handles this automatically.

> **Fix candidate:** Modified fields (values that differ from their compiled default) should be visually distinguished in the Settings → Appearance UI with a subtle accent tint. Not yet implemented.

---

## Prefs.qml

**File:** `Prefs.qml` (root, `pragma Singleton`)
**Persists to:** `~/.config/pillbox.conf`

### Appearance properties

| Property | Type | Default | Setter | Controls |
|---|---|---|---|---|
| `fontMono` | `string` | `"JetBrainsMono Nerd Font"` | `setFontMono(v)` | All text content |
| `fontNerd` | `string` | `"JetBrainsMono Nerd Font"` | `setFontNerd(v)` | Nerd Font glyphs |
| `fontSizePill` | `int` | `13` | `setFontSizePill(v)` | Pill text — independent of panel scale |
| `fontSizeBase` | `int` | `10` | `setFontSizeBase(v)` | Panel text scale anchor |
| `radiusScale` | `real` | `1.0` | `setRadiusScale(v)` | 0.0 = sharp · 0.5 = subtle · 1.0 = default |
| `pillBorderWidth` | `int` | `1` | `setPillBorderWidth(v)` | Pill container border only (0 / 1 / 2) |
| `borderWidth` | `int` | `1` | `setBorderWidth(v)` | Panel container borders (0 / 1 / 2) |
| `elementBorderWidth` | `int` | `1` | `setElementBorderWidth(v)` | Buttons, inputs within panels (0 / 1 / 2) |
| `borderColorMode` | `string` | `"subtle"` | `setBorderColorMode(v)` | `"subtle"` = `mat3OutlineVariant`; `"vibrant"` = `mat3Outline` for `borderFaintColor` |

Three separate border width settings so pill, panel container, and interactive-element chrome scale independently.

### Wallpaper properties

| Property | Type | Default | Setter |
|---|---|---|---|
| `wallpaperSourceType` | `string` | `"color"` | `setWallpaperSourceType(v)` |
| `wallpaperPath` | `string` | `""` | `setWallpaperPath(v)` |
| `wallpaperColor` | `string` | `"#2E3440"` | `setWallpaperColor(v)` |
| `wallpaperDir` | `string` | `""` | `setWallpaperDir(v)` |
| `slideshowInterval` | `int` | `60` | `setSlideshowInterval(v)` |

### Palette overrides ✅ Implemented

Per-slot palette overrides let users customise individual colors without replacing the whole theme.

```qml
// In Prefs._store:
property string color0Override: ""
// ... color1Override–color15Override (all 16 slots)

// In Style.qml Variable section:
readonly property color color0: Prefs.color0Override !== "" ? Prefs.color0Override : "#2E3440"
// ... color1–color15 same pattern
```

Override values are populated by `WallpaperProcess._maybeExtract()` via `matugen image --json hex --dry-run`. The 16 base16 slots (`base00`–`base0f`) map directly to `color0Override`–`color15Override`.

### Mat3 role overrides ✅ Implemented

12 additional string properties for Material Design 3 semantic roles, all defaulting to `""`:

| Prefs property | Setter | Mat3 role |
|---|---|---|
| `mat3PrimaryOverride` | `setMat3PrimaryOverride(v)` | `primary` |
| `mat3PrimaryContainerOverride` | `setMat3PrimaryContainerOverride(v)` | `primary_container` |
| `mat3BackgroundOverride` | `setMat3BackgroundOverride(v)` | `background` |
| `mat3OnBackgroundOverride` | `setMat3OnBackgroundOverride(v)` | `on_background` |
| `mat3SurfaceContainerLowOverride` | `setMat3SurfaceContainerLowOverride(v)` | `surface_container_low` |
| `mat3SurfaceContainerHighOverride` | `setMat3SurfaceContainerHighOverride(v)` | `surface_container_high` |
| `mat3OnSurfaceOverride` | `setMat3OnSurfaceOverride(v)` | `on_surface` |
| `mat3OnSurfaceVariantOverride` | `setMat3OnSurfaceVariantOverride(v)` | `on_surface_variant` |
| `mat3OutlineOverride` | `setMat3OutlineOverride(v)` | `outline` |
| `mat3OutlineVariantOverride` | `setMat3OutlineVariantOverride(v)` | `outline_variant` |
| `mat3ErrorOverride` | `setMat3ErrorOverride(v)` | `error` |
| `mat3ErrorContainerOverride` | `setMat3ErrorContainerOverride(v)` | `error_container` |

`clearMat3Overrides()` resets all 12 to `""`. Called by the Reset button and when `extractColors` is toggled off.

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

### Section 1.5 — Mat3 Roles

Between Variable and Fixed. Each property reads the Prefs override and falls back to a Nord-derived equivalent so the UI is stable when extraction is off.

| Token | Prefs override | Nord fallback |
|---|---|---|
| `mat3Primary` | `mat3PrimaryOverride` | `color10` |
| `mat3PrimaryContainer` | `mat3PrimaryContainerOverride` | `Qt.darker(color10, 2.4)` |
| `mat3Background` | `mat3BackgroundOverride` | `color0` |
| `mat3OnBackground` | `mat3OnBackgroundOverride` | `color6` |
| `mat3SurfaceContainerLow` | `mat3SurfaceContainerLowOverride` | `color1` |
| `mat3SurfaceContainerHigh` | `mat3SurfaceContainerHighOverride` | `color2` |
| `mat3OnSurface` | `mat3OnSurfaceOverride` | `color5` |
| `mat3OnSurfaceVariant` | `mat3OnSurfaceVariantOverride` | `color4` |
| `mat3Outline` | `mat3OutlineOverride` | `color3` |
| `mat3OutlineVariant` | `mat3OutlineVariantOverride` | `color1` |
| `mat3Error` | `mat3ErrorOverride` | `color11` |
| `mat3ErrorContainer` | `mat3ErrorContainerOverride` | `Qt.darker(color11, 2.4)` |

---

### Section 2 — Fixed (semantic tokens)

Semantic mappings over the Mat3 Roles section. Components always use these names. When the wallpaper changes and mat3 roles update, all Fixed tokens update automatically on the same frame.

#### Surfaces & Structure

| Token | Source | Role |
|---|---|---|
| `pillBgColor` | `mat3Background` | Pill window background |
| `panelBgColor` | `mat3Background` | Panel window background |
| `panelBorderColor` | `mat3OutlineVariant` | Panel outer border |
| `panelDividerColor` | `mat3OutlineVariant` | `PanelDivider` horizontal rule |
| `surfaceLowColor` | `mat3SurfaceContainerLow` | Raised section bg (`PanelCard`), hover rows |
| `surfaceMidColor` | `mat3SurfaceContainerHigh` | Buttons, text inputs, filter bar |

#### Borders

| Token | Source | Role |
|---|---|---|
| `borderFaintColor` | `mat3OutlineVariant` (subtle) or `mat3Outline` (vibrant) | Pill + panel container border — mode-driven by `Prefs.borderColorMode` |
| `borderSoftColor` | `mat3Outline` | Buttons, inputs |

`borderFaintColor` is the only mode-driven token. "Subtle" gives a near-invisible border matching the panel edge; "Vibrant" steps up one level for more definition.

#### Accent

| Token | Source | Role |
|---|---|---|
| `accentColor` | `mat3Primary` | Accent glyphs, active borders, today cell bg in calendar |
| `accentBgColor` | `mat3PrimaryContainer` | Selected/active bg (TogglePair selected, window switcher selection) |
| `accentBgHover` | `Qt.lighter(mat3PrimaryContainer, 1.3)` | Hover on accent interactive elements |
| `criticalBgColor` | `mat3ErrorContainer` | Error state tint (TimePill urgent, NotificationPill critical) |
| `successBgColor` | `Qt.darker(color14, 2.4)` | Positive state tint — no mat3 equivalent |

#### Text

The hierarchy maps onto mat3's own contrast gradient — `textMuted` is now genuinely dimmer than `textSecondary`.

| Token | Source | Role |
|---|---|---|
| `textPrimary` | `mat3OnBackground` | Headings, pill text |
| `textNormal` | `mat3OnSurface` | Standard body copy |
| `textSecondary` | `mat3OnSurfaceVariant` | Button labels, secondary info |
| `textMuted` | `mat3Outline` | Timestamps, section labels — dimmer than `textSecondary` |
| `textFaint` | `mat3OutlineVariant` | Barely-visible structural anchors |
| `textAccent` | `mat3Primary` | Links, highlighted text |
| `textCritical` | `mat3Error` | Error / alert state |
| `textSuccess` | `color14` | Positive / completion state — no mat3 equivalent |

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
| `pillBorderWidth` | `1` | Pill container border |
| `borderWidth` | `1` | Panel container borders |
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

| # | What | Where | Fix |
|---|---|---|---|
| 1 | Pill dimension tokens hardcoded | `PillWindow`, `MprisPill`, `WindowPill` | Add `pillHeight`, `pillPaddingH`, `pillTextMaxWidth`, `pillContentSpacing` to Style Fixed |
| 2 | Modified prefs fields have no accent tint | `SettingsPanel.qml` Appearance tab | Add subtle `accentBgColor` tint to fields whose value differs from the compiled default |
| ~~3~~ | ~~`textMuted` must change value~~ | ~~`Style.qml`~~ | **Fixed** — mat3 pipeline: `textMuted → mat3Outline` is genuinely dimmer than `textSecondary → mat3OnSurfaceVariant` |
| ~~4~~ | ~~`borderAccentColor` redundant~~ | ~~`Style.qml`~~ | **Fixed** — removed; callsites use `accentColor` |
| ~~5~~ | ~~`textWeekend` single-use~~ | ~~`Style.qml`~~ | **Fixed** — removed; CalendarPanel uses `accentColor` inline |
| ~~6~~ | ~~`dotIndicator` single-use~~ | ~~`Style.qml`~~ | **Fixed** — removed; CalendarPanel uses `accentColor` inline |
| ~~7~~ | ~~Preference changes do not persist~~ | ~~`Prefs.qml`~~ | **Fixed** — see completed.md |

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
