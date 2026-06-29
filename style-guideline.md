# Style Guideline

## 1. Colors

Strict Nord only. No off-palette values. All surface backgrounds use **90% opacity** so the wallpaper bleeds through. Defined in `quickshell/components/Style.qml`.

| Token | Hex | Description | TEXT | UI |
|---|---|---|---|---|
| `nord0` | `#2E3440` | Polar Night — darkest | TEXT — on highlighted background (`textOnHighlight`) | UI — wallpaper fallback, drop shadows, panel background (`rectNormalBg`) |
| `nord1` | `#3B4252` | Polar Night | — | UI — pill background (`rectMainBg`), panel border (`rectNormalBorder`) |
| `nord2` | `#434C5E` | Polar Night | — | UI — button background (`rectButtonBg`) |
| `nord3` | `#4C566A` | Polar Night — lightest | TEXT — dimmed, inactive, disabled (`textBodyLow`, `textHeaderLow`) | UI — borders (`rectMainBorder`, `rectButtonBorder`), divider lines |
| `nord4` | `#D8DEE9` | Snow Storm — darkest | TEXT — standard readable text (`textBodyNormal`, `textHeaderNormal`) | — |
| `nord5` | `#E5E9F0` | Snow Storm | — | — |
| `nord6` | `#ECEFF4` | Snow Storm — lightest | TEXT — high contrast on colored backgrounds (`textBright`) | — |
| `nord7` | `#8FBCBB` | Frost — teal | TEXT — accent, interactive, primary info (`textBodyHighlight`, `textHeaderHighlight`) | UI — selected row background |
| `nord8` | `#88C0D0` | Frost — ice blue | — | — |
| `nord9` | `#81A1C1` | Frost — soft blue | — | — |
| `nord10` | `#5E81AC` | Frost — deep blue | — | — |
| `nord11` | `#BF616A` | Aurora — red | TEXT — critical / alert (`textBodyCritical`, `textHeaderCritical`) | UI — recording pill background (`rectMainCriticalBg`) |
| `nord12` | `#D08770` | Aurora — orange | — | UI — recording pill border (`rectMainCriticalBorder`) |
| `nord13` | `#EBCB8B` | Aurora — yellow | — | — |
| `nord14` | `#A3BE8C` | Aurora — green | TEXT — success / completion (`textSuccess`) | — |
| `nord15` | `#B48EAD` | Aurora — purple | — | — |

---

## 2. UI Elements

Four surface layers, two text contexts, a handful of special tokens. All values live in `Style.qml` — no hardcoded colors anywhere else.

### Surfaces

| Element | Tokens | Background | Border | Used in |
|---|---|---|---|---|
| **Pill** | `rectMainBg` / `rectMainBorder` | Nord1 @ 90% | Nord3 @ 90% | The 24px bar module — normal state |
| **Pill critical** | `rectMainCriticalBg` / `rectMainCriticalBorder` | Nord11 @ 90% | Nord12 @ 90% | The 24px bar module — recording active |
| **Panel** | `rectNormalBg` / `rectNormalBorder` | Nord0 @ 90% | Nord1 @ 90% | Expanded panels below the pill (calendar, MPRIS, window switcher) |
| **Button** | `rectButtonBg` / `rectButtonBorder` | Nord2 @ 90% | Nord3 @ 90% | Interactive elements inside panels — filter input, focus button, hovered rows |

> Pill and Pill critical are for the 24px bar surface only. Everything that expands below it is a Panel. Clickable items inside a Panel are Buttons.

Border width is always **2px** (`rectBorderWidth`).

### Text

Split into **header** (text inside the pill) and **body** (text inside panels). Same colors, separate tokens so sizes and weights can diverge later.

| Token | Color | Use |
|---|---|---|
| `textHeaderLow` / `textBodyLow` | Nord3 | Dimmed — inactive states, disabled controls, secondary labels |
| `textHeaderNormal` / `textBodyNormal` | Nord4 | Default readable text |
| `textHeaderHighlight` / `textBodyHighlight` | Nord7 | Accent — interactive elements, primary info; also doubles as selection row background |
| `textHeaderCritical` / `textBodyCritical` | Nord11 | Alert text on a normal background |
| `textOnHighlight` | Nord0 | Text sitting on a Nord7 (highlight) background — selected rows |
| `textBright` | Nord6 | High contrast on a colored background (e.g. label on the Nord11 recording pill) |
| `textSuccess` | Nord14 | Completion / positive state |

### Base

| Constant | Value |
|---|---|
| `fontFamily` | JetBrainsMono Nerd Font |
| `fontSize` | 10pt |
| `rectBorderWidth` | 2px |
