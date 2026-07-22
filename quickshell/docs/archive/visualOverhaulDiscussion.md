# Visual Overhaul Discussion

## Intent

Work backward from the Settings panel — inspect every UI item, identify repeating visual patterns, extract each into a reusable element in `module-reusable-elements/`, then rebuild the panel using those elements. Once the pattern library is solid and the Settings panel is the proof-of-concept, carry the same approach panel by panel until the entire visual layer is consistent and MD3-compliant.

The goal is not a cosmetic pass. It is to establish a **composable, token-driven component system** where every interactive or structural element traces its color, spacing, and sizing back to a documented MD3 role via `Style.qml` semantic tokens — with no raw `mat3*` references appearing in components directly.

---

## Guiding Principles

### 1. Token pipeline is non-negotiable

```
mat3 role (matugen-generated)
  → Style.qml semantic token  (e.g. surfaceHoverColor, textOnAccent)
    → reusable element         (e.g. PanelButton, PanelCard)
      → panel                  (e.g. SettingsPanel)
```

Components never reference `mat3*` roles directly. If a color doesn't have a semantic token yet, add one before using it.

### 2. MD3 hover = state layer, not solid swap

Hover states must be semi-transparent overlays of the content color at 8% opacity, composited over the resting container:

- Default/outlined → `Qt.rgba(mat3Primary.r, mat3Primary.g, mat3Primary.b, 0.08)` → `Style.surfaceHoverColor`
- Filled tonal (accent) → `Qt.tint(mat3PrimaryContainer, Qt.rgba(mat3OnPrimaryContainer.r, ..., 0.08))` → `Style.accentBgHover`
- Critical → `Qt.rgba(mat3Error.r, mat3Error.g, mat3Error.b, 0.08)` → `Style.criticalHoverColor`

Never use a solid surface fill (`surfaceLowColor`, `surfaceMidColor`) as a hover state on a button.

### 3. Padding tokens separate concerns

Three categories of padding, each with distinct scope:

- **`Prefs.pillPaddingV`** (user-adjustable, default 20) — vertical padding added to `fontSizePill` to determine pill height. Lives in Prefs because the user controls it via Settings.
- **`Style.panelElementHpadding` (20) / `Style.panelElementVpadding` (8)** — padding for interactive panel elements (buttons, value chips, etc.). Currently hardcoded in Style.
- **`Style.panelCardHpadding` (12) / `Style.panelCardVpadding` (12)** — padding between `PanelCard`'s edge and its content. Currently hardcoded in Style.

These two concerns must not be mixed. `pillPaddingV` must never be used to size panel elements.

### 4. WheelHandler pattern

`WheelHandler` must be a child of a `Rectangle` or `Item`, never a `Text`. It requires:

```qml
WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: (event) => {
        // ...
        event.accepted = true
    }
}
```

The `event.accepted = true` prevents propagation to parent containers. `Text` elements do not receive wheel events — always wrap the scrollable target in a `Rectangle`.

### 5. Button interaction is composable

`PanelButton` handles click (via `TapHandler`) and hover appearance internally. Any additional interaction (scroll, right-click, long-press) is added by the caller as a child PointerHandler — no subclass needed:

```qml
PanelButton {
    label: "Vol"
    onClicked: muteToggle()

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => { adjustVolume(event.angleDelta.y) }
    }
}
```

---

## Work Completed (Pre-Overhaul Fixes)

These were fixed during the discussion that led to this plan. They are not part of the formal overhaul but establish the baseline.

### Pill height dynamic
- `PillWindow.qml`: `implicitHeight` changed from hardcoded `24` to `Style.fontSizePill + Style.pillPaddingV`
- `Prefs.qml`: added `pillPaddingV` (default 20), public read, `setPillPaddingV()` setter
- `Style.qml`: added `pillPaddingV` token proxied from Prefs
- Settings font size cap raised from 18 → 24 (height is now dynamic)
- Settings Appearance tab added "Padding" section with scroll-driven Pill padding control (4–50px)

### Settings tab order
- "Appearance" is now the default (first) tab; "Services" is second.

### PanelButton MD3 compliance
- `textOnAccent: mat3OnPrimaryContainer` added to Style.qml — used for text on `primaryContainer` backgrounds
- Accent variant text: was `textMuted` (`mat3Outline`), now `textOnAccent` (`mat3OnPrimaryContainer`)
- Hover colors: all three variants now use proper MD3 semi-transparent state layers
- Border: removed from `accent` and `critical` variants (only `default` keeps it, per MD3)
- `implicitWidth`: `Math.min(Math.max(_content.implicitWidth + Style.panelElementHpadding, 24), 300)`
- `implicitHeight`: `Math.max(Style.buttonHeight, _content.implicitHeight + Style.panelElementVpadding)`
- Added `"text"` variant: transparent bg, `textAccent` (`mat3Primary`) text, no border, `surfaceHoverColor` hover

### Style.qml new tokens
- `textOnAccent: mat3OnPrimaryContainer`
- `surfaceHoverColor: Qt.rgba(mat3Primary, 8%)`
- `criticalHoverColor: Qt.rgba(mat3Error, 8%)`
- `accentBgHover: Qt.tint(mat3PrimaryContainer, rgba(mat3OnPrimaryContainer, 8%))`
- `buttonHeight: 24` (was 22)
- `panelElementHpadding: 20` (total horizontal padding, 10px/side)
- `panelElementVpadding: 8` (total vertical padding, 4px/side)

### Known pending fix
- The Padding section in SettingsPanel still has a broken WheelHandler — it is inside a `Text` element. It needs to be moved to a `Rectangle` container following the WheelHandler pattern above. This fix is intentionally deferred to be done as part of the Settings panel overhaul, so the value chip can be built as a proper reusable element.

---

## MD3 Button Inventory

Five MD3 button types, mapped to `PanelButton` variants:

| MD3 Type | PanelButton variant | bg (rest) | text | border | hover |
|---|---|---|---|---|---|
| Outlined | `"default"` | transparent | `textSecondary`* | `outline` | `surfaceHoverColor` |
| Filled Tonal | `"accent"` | `primaryContainer` | `onPrimaryContainer` | none | `accentBgHover` |
| (Destructive) | `"critical"` | transparent | `error` | none | `criticalHoverColor` |
| Text | `"text"` | transparent | `primary` | none | `surfaceHoverColor` |

*MD3 spec uses `primary` for outlined button text; this codebase uses `textSecondary` (`onSurfaceVariant`) for a more subdued, desktop-appropriate feel. This is an intentional deviation.

`IconButton` is a candidate for deletion. `PanelButton` with a single glyph label covers the same use case. No action yet.

---

## Settings Panel — Pattern Analysis

This is the active work. The goal is to identify every distinct visual pattern in the Settings panel and define a reusable element for each.

### Patterns identified so far

**Section header**
```qml
Text {
    text: "..."
    color: Style.textPrimary
    font.family: Style.fontMono
    font.pixelSize: Style.fontSizeHeading
    font.bold: true
}
```
Appears before every logical group. Distinct from `SectionLabel` (which is muted, uppercase, subtle-sized — used inside cards).

**Row label**
```qml
Text {
    text: "..."
    color: Style.textSecondary
    font.family: Style.fontMono
    font.pixelSize: Style.fontSizeBody
    Layout.minimumWidth: 80  // or 72, inconsistent
}
```
Left side of every settings row. The minimum width varies (72 or 80) — should be standardised.

**Value chip (scroll-driven)**
A `Rectangle` containing a `Text` label, with `WheelHandler` for +1/−1 adjustment and `HoverHandler` for `SizeVerCursor`. Used for numeric preferences like pill padding. Currently partially built (WheelHandler is broken — see pending fix above).

**Button group row**
A `RowLayout` of `PanelButton` elements with `Layout.fillWidth: true` on each, used for mutually-exclusive choices (e.g. Off / Thin / Thick for borders, None / Subtle / Default for corner rounding).

**Settings row wrapper**
A `RowLayout` with `Layout.fillWidth: true`, `spacing: 6`, containing a row label on the left, a spacer (`Item { Layout.fillWidth: true }`), and a control on the right.

**PanelCard**
Redesigned reusable element. Uses `default property alias content: _inner.data` — callers drop children directly without `y:` offsets or margin anchors. Internal `Item` handles `hpadding`/`vpadding` via anchors. `implicitHeight` is `_inner.y + _inner.height + vpadding` (explicit, no `childrenRect` fragility). Callers set `Layout.fillWidth: true` at the callsite; the component does not force it.

### Open questions before building
- What should the `Layout.minimumWidth` standard be for row labels? (currently 72 or 80 inconsistently)
- Should the section header be extracted as a reusable element, or is a raw `Text` acceptable given it's already three lines?
- What other control types exist beyond button groups, scroll chips, font pickers, and toggle pairs?

---

## Execution Plan

1. **Audit Settings panel completely** — list every unique control type, note inconsistencies (label widths, spacing, etc.)
2. **Define reusable elements** — for each pattern, decide: extract to `module-reusable-elements/` or keep inline
3. **Fix pending WheelHandler bug** in the Padding section as part of building the value chip element
4. **Rebuild SettingsPanel.qml** using the new element library
5. **Carry forward** — apply the same element library to each remaining panel in turn

---

## File References

| File | Role |
|---|---|
| `Style.qml` | Token definitions — all semantic colors, spacing, typography |
| `Prefs.qml` | User-adjustable preferences — font sizes, padding, border widths |
| `module-reusable-elements/PanelButton.qml` | Primary interactive button |
| `module-reusable-elements/IconButton.qml` | Icon-only square button (deletion candidate) |
| `module-reusable-elements/PanelCard.qml` | Card container for settings groups |
| `module-reusable-elements/SectionLabel.qml` | Small muted uppercase label (used inside cards, not as section headers) |
| `module-panels/SettingsPanel.qml` | First target for overhaul |
