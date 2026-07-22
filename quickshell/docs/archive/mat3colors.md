# Material Design 3 Color Workflow

> **ARCHIVED** — This document was a planning/design doc. The pipeline described here has been fully implemented. For the authoritative current state see:
> - `docs/style-system.md` — Section 1.5 (Mat3 Roles), Fixed section redesign, Prefs extensions
> - `docs/completed.md` — "Material Design 3 Color Pipeline" entry (reverse-chronological)
>
> This file is kept as a historical record of the design intent.

---

How to wire matugen's mat3 semantic roles through the Pillbox theme pipeline so that the entire UI recolors correctly from any wallpaper — not just Nord-like palettes.

## Scope

This document covers **colors only** — the first phase of the visual layer work.

Style.qml contains five other non-color concerns that are out of scope here and will get a separate plan once colors are stable:

| Concern | Current state |
|---|---|
| Font families (`fontMono`, `fontNerd`, `fontCJK`) | Prefs-driven, working |
| Typography scale (`fontSizeBody`, `fontSizeHeading`, etc.) | Prefs-driven, working |
| Radius (`radSm`, `radMd`, `radLg`) | Prefs-driven via `radiusScale`, working |
| Border widths (`borderWidth`, `elementBorderWidth`) | Prefs-driven, working |
| Layout constants (`buttonHeight`, `panelMargin`, pill dimensions) | Partially hardcoded — `pillHeight`, `pillPaddingH`, `pillTextMaxWidth`, `pillContentSpacing` still live in individual components |

---

## Why mat3, not just base16

The current pipeline already extracts 16 base16 slots from matugen and maps them to Nord-derived semantic tokens (`textPrimary: color6`, `accentColor: color10`, etc.). Those mappings are Nord-specific heuristics. They work when matugen outputs a palette that happens to follow Nord's structure, but they break on saturated or warm-toned wallpapers where the "sixth slot" is not white text and the "tenth slot" is not a blue accent.

matugen also emits a `colors` section with proper Material Design 3 semantic roles: `primary`, `on_background`, `outline`, etc. These carry *intent*, not just slot positions. Wiring them through Prefs → Style replaces the heuristics with a principled mapping that works for any wallpaper.

---

## Pipeline Overview

```
matugen image --json hex --dry-run <path>
    │
    │  data.colors.<role>.dark.color  (12 roles)
    ▼
WallpaperProcess.qml   — parse mat3 roles, call Prefs setters
    ▼
Prefs.qml              — persist mat3*Override strings to pillbox.conf
    ▼
Style.qml Section 1.5  — mat3 role properties with colorN fallbacks
    ▼
Style.qml Fixed        — semantic tokens derive from mat3 roles
    ▼
All pills + panels     — no changes; they read Style.* as before
```

The base16 slots (`color0`–`color15`) stay in place. The fallbacks in Section 1.5 derive from them, so the UI keeps Nord defaults when `extractColors` is off or when matugen is not installed.

---

## matugen JSON Structure (verified v4.1.0)

```
matugen image --json hex --dry-run --source-color-index 0 <path>
```

Top-level keys: `base16`, `colors`, `image`, `is_dark_mode`, `mode`, `palettes`

mat3 roles live at:
```
data.colors.<role>.dark.color   →  "#rrggbb"
```

Example:
```json
{
  "colors": {
    "primary":               { "dark": { "color": "#c8bfff" }, ... },
    "primary_container":     { "dark": { "color": "#473f77" }, ... },
    "background":            { "dark": { "color": "#141318" }, ... },
    "on_background":         { "dark": { "color": "#e5e1e9" }, ... },
    "surface_container_low": { "dark": { "color": "#1c1b20" }, ... },
    "surface_container_high":{ "dark": { "color": "#2b292f" }, ... },
    "on_surface":            { "dark": { "color": "#e5e1e9" }, ... },
    "on_surface_variant":    { "dark": { "color": "#c9c5d0" }, ... },
    "outline":               { "dark": { "color": "#928f99" }, ... },
    "outline_variant":       { "dark": { "color": "#48454f" }, ... },
    "error":                 { "dark": { "color": "#ffb4ab" }, ... },
    "error_container":       { "dark": { "color": "#93000a" }, ... }
  }
}
```

---

## Step 1 — WallpaperProcess.qml

In `matugenProc.stdout.onStreamFinished`, after the existing base16 loop, add:

```js
if (data.colors) {
    var mat3Map = {
        "primary":                "setMat3PrimaryOverride",
        "primary_container":      "setMat3PrimaryContainerOverride",
        "background":             "setMat3BackgroundOverride",
        "on_background":          "setMat3OnBackgroundOverride",
        "surface_container_low":  "setMat3SurfaceContainerLowOverride",
        "surface_container_high": "setMat3SurfaceContainerHighOverride",
        "on_surface":             "setMat3OnSurfaceOverride",
        "on_surface_variant":     "setMat3OnSurfaceVariantOverride",
        "outline":                "setMat3OutlineOverride",
        "outline_variant":        "setMat3OutlineVariantOverride",
        "error":                  "setMat3ErrorOverride",
        "error_container":        "setMat3ErrorContainerOverride"
    }
    Object.keys(mat3Map).forEach(function(role) {
        var entry = data.colors[role]
        if (entry && entry.dark) Prefs[mat3Map[role]](entry.dark.color)
    })
    console.log("[WallpaperProcess] mat3 roles extracted")
}
```

---

## Step 2 — Prefs.qml

Add 12 new string properties to `_store` (all default `""`):

```qml
property string mat3PrimaryOverride:              ""
property string mat3PrimaryContainerOverride:     ""
property string mat3BackgroundOverride:           ""
property string mat3OnBackgroundOverride:         ""
property string mat3SurfaceContainerLowOverride:  ""
property string mat3SurfaceContainerHighOverride: ""
property string mat3OnSurfaceOverride:            ""
property string mat3OnSurfaceVariantOverride:     ""
property string mat3OutlineOverride:              ""
property string mat3OutlineVariantOverride:       ""
property string mat3ErrorOverride:                ""
property string mat3ErrorContainerOverride:       ""
```

Add matching public `readonly property string` aliases and 12 setters:

```qml
readonly property string mat3PrimaryOverride: _store.mat3PrimaryOverride
// ... repeat for all 12
function setMat3PrimaryOverride(v)              { _store.mat3PrimaryOverride              = v }
// ... repeat for all 12
```

Add a reset function:

```qml
function clearMat3Overrides() {
    _store.mat3PrimaryOverride              = ""
    _store.mat3PrimaryContainerOverride     = ""
    _store.mat3BackgroundOverride           = ""
    _store.mat3OnBackgroundOverride         = ""
    _store.mat3SurfaceContainerLowOverride  = ""
    _store.mat3SurfaceContainerHighOverride = ""
    _store.mat3OnSurfaceOverride            = ""
    _store.mat3OnSurfaceVariantOverride     = ""
    _store.mat3OutlineOverride              = ""
    _store.mat3OutlineVariantOverride       = ""
    _store.mat3ErrorOverride                = ""
    _store.mat3ErrorContainerOverride       = ""
}
```

The future "Reset palette" button should call both `clearColorOverrides()` and `clearMat3Overrides()`.

---

## Step 3 — Style.qml

### 3a — New Section 1.5: Mat3 Roles

Insert between Variable and Fixed. Each property reads the Prefs override and falls back to the equivalent colorN-derived Nord value, so the UI is stable when extraction is off:

```qml
// =========================================================================
// ─── Mat3 Roles (populated by matugen; fall back to colorN when unset) ───
// =========================================================================
readonly property color mat3Primary:              Prefs.mat3PrimaryOverride              !== "" ? Prefs.mat3PrimaryOverride              : style.color10
readonly property color mat3PrimaryContainer:     Prefs.mat3PrimaryContainerOverride     !== "" ? Prefs.mat3PrimaryContainerOverride     : Qt.darker(style.color10, 2.4)
readonly property color mat3Background:           Prefs.mat3BackgroundOverride           !== "" ? Prefs.mat3BackgroundOverride           : style.color0
readonly property color mat3OnBackground:         Prefs.mat3OnBackgroundOverride         !== "" ? Prefs.mat3OnBackgroundOverride         : style.color6
readonly property color mat3SurfaceContainerLow:  Prefs.mat3SurfaceContainerLowOverride  !== "" ? Prefs.mat3SurfaceContainerLowOverride  : style.color1
readonly property color mat3SurfaceContainerHigh: Prefs.mat3SurfaceContainerHighOverride !== "" ? Prefs.mat3SurfaceContainerHighOverride : style.color2
readonly property color mat3OnSurface:            Prefs.mat3OnSurfaceOverride            !== "" ? Prefs.mat3OnSurfaceOverride            : style.color5
readonly property color mat3OnSurfaceVariant:     Prefs.mat3OnSurfaceVariantOverride     !== "" ? Prefs.mat3OnSurfaceVariantOverride     : style.color4
readonly property color mat3Outline:              Prefs.mat3OutlineOverride              !== "" ? Prefs.mat3OutlineOverride              : style.color3
readonly property color mat3OutlineVariant:       Prefs.mat3OutlineVariantOverride       !== "" ? Prefs.mat3OutlineVariantOverride       : style.color1
readonly property color mat3Error:                Prefs.mat3ErrorOverride                !== "" ? Prefs.mat3ErrorOverride                : style.color11
readonly property color mat3ErrorContainer:       Prefs.mat3ErrorContainerOverride       !== "" ? Prefs.mat3ErrorContainerOverride       : Qt.darker(style.color11, 2.4)
```

### 3b — Redesigned Fixed Section (Option B)

The mat3 roles define the semantics here, not the other way around. We're not finding the closest colorN substitute for each existing token name — we're asking "what does mat3 say this surface/text/border role should be?" and naming the token to match that intent.

Three open fix candidates get resolved as side effects: `borderAccentColor` removed, `textWeekend` and `dotIndicator` removed from Style (both move inline in CalendarPanel).

#### Surfaces & Structure

| Token | Source | Old source | Notes |
|---|---|---|---|
| `pillBgColor` | `mat3Background` | `color0` | |
| `panelBgColor` | `mat3Background` | `color0` | |
| `panelBorderColor` | `mat3OutlineVariant` | `color1` | |
| `panelDividerColor` | `mat3OutlineVariant` | `color2` | now same value as `panelBorderColor` — mat3 treats panel edges and internal dividers at the same visual weight |
| `surfaceLowColor` | `mat3SurfaceContainerLow` | `color1` | hover rows, PanelCard |
| `surfaceMidColor` | `mat3SurfaceContainerHigh` | `color2` | buttons, inputs, filter bar |

#### Borders

| Token | Source | Old source | Notes |
|---|---|---|---|
| `borderFaintColor` | `mat3OutlineVariant` | `color1` | |
| `borderSoftColor` | `mat3Outline` | `color3` | |
| ~~`borderAccentColor`~~ | — | `color10` | **removed** — callsites use `accentColor` directly |

#### Accent

| Token | Source | Old source | Notes |
|---|---|---|---|
| `accentColor` | `mat3Primary` | `color10` | |
| `accentBgColor` | `mat3PrimaryContainer` | `Qt.darker(color10, 2.4)` | selected/active bg |
| `accentBgHover` | `Qt.lighter(mat3PrimaryContainer, 1.3)` | `Qt.darker(color10, 1.8)` | no mat3 hover role; derived |
| `criticalBgColor` | `mat3ErrorContainer` | `Qt.darker(color11, 2.4)` | |
| `successBgColor` | `Qt.darker(color14, 2.4)` | unchanged | no mat3 equivalent |

#### Text

The text hierarchy now maps cleanly onto mat3's own contrast gradient — no more `textMuted == textSecondary`:

| Token | Source | Old source | Notes |
|---|---|---|---|
| `textPrimary` | `mat3OnBackground` | `color6` | headings, pill text |
| `textNormal` | `mat3OnSurface` | `color5` | standard body |
| `textSecondary` | `mat3OnSurfaceVariant` | `color4` | labels, secondary info |
| `textMuted` | `mat3Outline` | `color4` | **fix resolved**: outline is genuinely dimmer than on_surface_variant, so textMuted < textSecondary in contrast for the first time |
| `textFaint` | `mat3OutlineVariant` | `color2` | barely-visible structural anchors — reuses border color |
| `textAccent` | `mat3Primary` | `color9` | links, highlighted text |
| `textCritical` | `mat3Error` | `color11` | |
| `textSuccess` | `color14` | unchanged | no mat3 equivalent |
| ~~`textWeekend`~~ | — | `color10` | **removed** — CalendarPanel uses `accentColor` inline |
| ~~`dotIndicator`~~ | — | `color8` | **removed** — CalendarPanel uses `accentColor` inline (event dots get the accent color) |

---

## Step 4 — Minimal component touch-ups

Most of Style's Fixed token names are unchanged, so most components need no edits. The exceptions:

**CalendarPanel** — remove references to `Style.textWeekend` and `Style.dotIndicator`; replace inline with `Style.accentColor` and `Style.accentColor` respectively.

**Any callsite of `Style.borderAccentColor`** — replace with `Style.accentColor`.

**Direct palette references that stay valid** (base16 slots still exist and still receive matugen extraction):
- `NotificationPill`: `Qt.darker(Style.color11, 1.5)` — intentional; pill scale needs a lighter darkening factor than `criticalBgColor` (see completed.md)
- `NotificationPanel`: `Qt.rgba(Style.color11.r, …, 0.15)` — translucent critical tint; `color11` still populated by base16 extraction

---

## Verification

1. Enable **Extract colors** in Settings → Appearance
2. Pick any wallpaper image in WallpaperPanel
3. Check logs — both lines should appear:
   ```
   [WallpaperProcess] palette extracted from <path>
   [WallpaperProcess] mat3 roles extracted
   ```
4. Confirm 12 `mat3*Override` keys written to `~/.config/pillbox.conf`
5. Visual check: pill background, panel surfaces, borders, text hierarchy, and accent elements all track the wallpaper's Material You palette
6. Pick a second visually different wallpaper (e.g. warm vs. cool) and confirm the whole shell recolors
7. Disable **Extract colors** → shell reverts to Nord defaults (mat3 slots stay in conf but the ternaries in Section 1.5 select the colorN fallback)
8. Verify `clearColorOverrides()` + `clearMat3Overrides()` from the QML console resets everything cleanly
