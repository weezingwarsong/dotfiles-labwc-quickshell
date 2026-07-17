# Panel Audit — Qt Quick Layouts Standardization

**Scope:** PanelSurface → ControlPanel → all reusable elements → CalendarPanel, MediaPlayerPanel, SettingsPanel, WallpaperPanel, NotificationPanel, SysTrayBar, TimerWidget.

**Excluded:** WindowSwitcherPanel, toast stack, audio visualiser, pill stack.

**Reference:** https://doc.qt.io/qt-6/qtquicklayouts-index.html

---

## V2 Rework Plan

Major architectural refactor. Work in this order — each step unblocks the next.

### Phase 1 — PanelSurface / PanelContainer

- [x] **1a. Rename `_container` id to `panelContainer`** in PanelSurface.qml
- [x] **1b. Move panel chrome to PanelContainer** — add background `Rectangle` (color, radius, border) directly in PanelSurface around the Loader slot
- [x] **1c. Build the unified ColumnLayout** — NavBar as first row, Loader as second row; PanelContainer owns both
- [ ] **1d. Strip NavBar from all panel modules** — remove `PanelNavBar` instantiation and its `navigateRequested` wiring from every panel module (CalendarPanel, ControlPanel, MediaPlayerPanel, SettingsPanel, WallpaperPanel, NotificationPanel) — SettingsPanel + ControlPanel + MediaPlayerPanel done; Calendar, Wallpaper, Notification remain
- [ ] **1e. Strip background Rectangle from all panel modules** — each module becomes a pure content ColumnLayout with no chrome — SettingsPanel + ControlPanel + MediaPlayerPanel done; Calendar, Wallpaper, Notification remain

### Phase 2 — Reusable Elements Classification

- [ ] **2a. Document classification** in `docs/components.md` — three buckets:
  - **Infrastructure** — PillWindow, PanelSurface, HoverZone, PillController, PanelController, ToastWindow, ToastController (structural, not visual atoms)
  - **Panel chrome** — PanelTabBar, PanelDivider, PanelCard, SectionHeader, SectionLabel, RowLabel (build panel page layouts; use `Layout.*` attached props)
  - **Controls / atoms** — PanelButton, IconButton, TogglePair, SegmentedControl, ScrollChip, ScrollingText, FontPicker, StatusDot, MediaThumbnail (leaf elements; declare `implicitWidth`/`implicitHeight`, caller decides layout behavior)
- [ ] **2b. Verify each atom declares `implicitWidth` + `implicitHeight`** — no Layout-specific defaults baked in

### Phase 3 — Layout Standardization (Audit Fixes)

Apply the audit findings from the priority table below, one component at a time.

- [x] **3a. ControlPanel** — fix conflicting anchors on network Text; fix bare `height` on network Rectangle
- [x] **3b. MediaPlayerPanel** — fix bare `width`/`height` on `_volBtn` and `_marqueeClip`; layout rework: chrome stripped, art 90% square centered, "No active player" row with music IconButton (⚠️ hover interaction pending physical test)
- [x] **3c. TimerWidget** — fix bare `height` on all ColumnLayout children; replaced Rectangle+MouseArea buttons with TogglePair (mode), IconButton (start/stop), ScrollChip (duration), PanelButton (reset) in 2×2 GridLayout
- [ ] **3d. SettingsPanel** — fix filter Row positioner; fix wallpaper input bare `height`
- [x] **3e. CalendarPanel** — fix `anchors.fill` in all three Flickables; remove background Rectangle chrome (phase 1e); remove PanelNavBar (phase 1d)
- [x] **3f. PanelTabBar** — replace `Row { anchors.fill }` + manual widths with `RowLayout`; add `glyphs` property with collapsible glyph row per tab
- [x] **3g. ScrollChip** — replace `Row { anchors }` with `RowLayout`; remove anchors-in-positioner; fix `implicitHeight: Style.buttonHeight` → `Style.fontSizeBody + Style.panelElementVpadding`
- [x] **3h. SectionHeader** — remove redundant `anchors.verticalCenter` inside `Row`
- [x] **3i. PanelNavBar** — replace `Row` with `RowLayout` for dot indicators
- [x] **3j. PanelCard** — replace `childrenRect.height` with layout-safe sizing

### Phase 4 — Panel Module Content Rework

Individual panel content rewrites. Order TBD based on priority.

- [ ] **4a. ControlPanel** — screenrec section rewrite (was step 7 in screenrecDiscussion.md)
- [ ] **4b. MediaPlayerPanel** — progress bar, track time, layout polish
- [ ] Other panels as needed

---

## The Rules We're Standardizing On

1. Items inside a `RowLayout` / `ColumnLayout` must size themselves via `implicitWidth`/`implicitHeight` or `Layout.preferredWidth`/`Layout.preferredHeight` — **not** bare `width`/`height`.
2. Never put a positioner (`Row`, `Column`, `Grid`) inside a Layout if you expect it to fill or flex. Use `RowLayout`/`ColumnLayout` instead.
3. Do not use `anchors` on items that are direct Layout children (except `Layout.alignment` which is fine). `anchors.fill` inside a Layout child overrides the layout.
4. Inside a `Flickable`, the content item should be anchored only on `left`, `right`, and `top` — not `.fill` (which would constrain height to the viewport).
5. `childrenRect.height` is unreliable when children use layouts — use explicit `implicitHeight` from a layout root instead.
6. Do not use conflicting anchors (`anchors.centerIn` + `anchors.left/right`) on the same item.

---

## Status Legend

- ✅ Clean — no issues
- ⚠️ Anti-pattern — works today but fragile or misleading
- 🔴 Bug — likely to cause sizing or rendering problems

---

## PanelSurface.qml

**Status: ✅ Clean**

Top-level `PanelWindow` — fullscreen overlay, not layout-managed. `Item _container` with explicit `x`, `y`, `width`, `height`. `Loader` with explicit `width`, `height: Math.min(item.implicitHeight, maxHeight)`. This is correct window-level geometry, not a Layout context.

---

## Reusable Elements

### FontPicker.qml ✅

`Item` root with `implicitHeight: Style.fontSizeBody + Style.panelElementVpadding`. Caller sets `Layout.preferredWidth: parent.width * 0.6` — no Layout baked in. No Layout issues.

---

### IconButton.qml ✅

`Rectangle` root. `implicitWidth/Height: Style.fontSizeBody + Style.panelElementVpadding` — scales with typography, fixed padding. Three variants: `default`, `critical`, `important`. md3 colour states: rest/hover/pressed. Tooltip support. No border. No Layout issues.

---

### PanelButton.qml ✅

`Rectangle` root. Content is `Row { anchors.centerIn: parent }` inside the Rectangle — this is fine, `Row` is positioned within a Rectangle, not inside a Layout. Uses `implicitWidth` and `implicitHeight`.

---

### PanelCard.qml ⚠️

```qml
Rectangle {
    implicitHeight: _inner.y + _inner.height + vpadding

    Item {
        id: _inner
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: childrenRect.height    // ← fragile
    }
}
```

`childrenRect.height` is fragile when children use layouts (Qt computes it from rendered positions, which may not reflect layout's desired implicit height before a layout pass). Works today because content is typically a `ColumnLayout` with fixed children, but will break if content ever uses `Layout.fillHeight` or animated sizing.

**Fix:** Replace `_inner` with a `ColumnLayout` that sets `implicitHeight` natively, or bind `_inner.height` to its single ColumnLayout child's `implicitHeight`.

---

### PanelDivider.qml ✅

`Rectangle` with `Layout.fillWidth: true` and `height: 1`. The `height` directly on a Rectangle root is correct (not a Layout child itself). Fine.

---

### PanelNavBar.qml ✅

```qml
ColumnLayout {
    RowLayout {
        IconButton {}
        Item { Layout.fillWidth: true }
        Row {                           // ← positioner inside Layout
            spacing: 4
            Repeater { model: _order.length; Text { ... } }
        }
        Item { Layout.fillWidth: true }
        IconButton {}
    }
}
```

`Row` inside `RowLayout`. `Row` does compute `implicitWidth` from its children so the RowLayout can read it, and the spacer Items flank it — this works in practice. But it's inconsistent with the layout-only goal.

**Fix:** Replace `Row` with `RowLayout` (or just `Item { implicitWidth: ...; RowLayout { anchors.fill: parent } }` if spacing is already right).

---

### PanelTabBar.qml ✅

```qml
Item {
    implicitHeight: Style.buttonHeight
    Layout.fillWidth: true

    Row {
        id: _row
        anchors.fill: parent           // ← anchors on positioner
        Repeater {
            delegate: Item {
                width: _row.width / root.labels.length   // ← manual equal-width division
                height: _row.height
            }
        }
    }
}
```

Two issues:
1. `anchors.fill` on a `Row` — anchors constrain the Row's geometry externally while the Row tries to size from its children. The `width` ends up anchor-set, which the delegate `Item`s read via `_row.width`. Works today.
2. Manual `width: _row.width / labels.length` — fragile division; breaks if `labels` changes without a re-layout.

**Fix:** Replace `Row` + manual division with `RowLayout` + delegate using `Layout.fillWidth: true`.

```qml
RowLayout {
    id: _row
    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
    spacing: 0
    Repeater {
        delegate: Item {
            Layout.fillWidth: true
            implicitHeight: Style.buttonHeight
            ...
        }
    }
}
```

---

### RowLabel.qml ✅

`RowLayout` root. `Layout.minimumWidth` on the label text is correct. No issues.

---

### ScrollChip.qml ✅

`Rectangle` root. `implicitHeight: Style.fontSizeBody + Style.panelElementVpadding` — scales with typography. Bar variant label uses `RowLayout { anchors { left, right, verticalCenter } }` with glyph `Text` (auto-sized from `implicitWidth`) and label `Text { Layout.fillWidth: true }`. Value variant uses `Text { anchors.centerIn: parent }`. No Layout issues.

---

### ScrollingText.qml ✅

`Item` root. No Layout issues.

---

### SectionHeader.qml ✅

```qml
Item {
    Row {
        id: _row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Text { ... anchors.verticalCenter: parent.verticalCenter }   // ← inside positioner
        Text { ... anchors.verticalCenter: parent.verticalCenter }   // ← inside positioner
    }
}
```

`anchors.verticalCenter` on items inside a `Row` — Row already centers children vertically by default. These anchors are redundant and mix positioner + anchor systems. Not breaking, but unclean.

**Fix:** Remove `anchors.verticalCenter: parent.verticalCenter` from both Text items inside the Row. Or replace `Row` with `RowLayout`.

---

### SectionLabel.qml ✅

Simple `Text` root. Callers add `Layout.*` attached properties as needed. No issues.

---

### SegmentedControl.qml ✅

`RowLayout` root. Delegates use `implicitWidth` and `implicitHeight`. Clean.

---

### StatusDot.qml ✅

`Rectangle` with explicit `width: 8; height: 8`. Fixed-size intentional. No issues.

---

### TogglePair.qml ✅

`Item` root with `implicitWidth` and `implicitHeight`. Content is animation-driven `Text` items positioned via `x`. No Layout issues.

---

## Panel Modules

### CalendarPanel.qml ⚠️

Three Flickables (`glanceFlick`, `timerFlick`, `expandedFlick`) all follow the same pattern:

```qml
Flickable {
    anchors.fill: parent
    contentHeight: col.implicitHeight    // driven by layout

    ColumnLayout {
        id: col
        anchors.fill: parent             // ← fills Flickable viewport, not content area
        anchors.margins: 12
    }
}
```

`anchors.fill: parent` inside a Flickable sets the layout's size to the Flickable's *visible* height (viewport), not its content size. Qt resolves this because `implicitHeight` is independent of `height`, but it creates a circular sizing relationship. Also, if `contentWidth` is not set on the Flickable, the layout gets width = 0 in theory.

**Fix:** Replace `anchors.fill: parent` with only horizontal+top anchoring, and set `contentWidth` explicitly:
```qml
Flickable {
    anchors.fill: parent
    contentWidth: width
    contentHeight: col.implicitHeight

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        // No height anchor — implicitHeight drives contentHeight above
    }
}
```

---

### ControlPanel.qml 🔴⚠️

**Bug — conflicting anchors on network Text (line 95–112):**

```qml
Text {
    anchors.centerIn: parent     // ← conflicts with directional anchors below
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 6
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    ...
}
```

`anchors.centerIn` sets both horizontal and vertical center. `anchors.left/right` then override the horizontal position. Qt logs a warning and the behavior is undefined — one set wins. The correct intent is to center vertically and stretch horizontally.

**Fix:** Remove `anchors.centerIn`, replace with `anchors { left, right, verticalCenter, margins: 6 }`.

**Anti-pattern — bare `height` on ColumnLayout child (line 85–88):**

```qml
Rectangle {
    Layout.fillWidth: true
    height: Style.buttonHeight    // ← should be Layout.preferredHeight
    ...
}
```

Inside a `ColumnLayout`, child height should be set via `implicitHeight` or `Layout.preferredHeight`. Bare `height` can conflict with the layout engine.

**Fix:** Change to `implicitHeight: Style.buttonHeight` or add `Layout.preferredHeight: Style.buttonHeight`.

---

### MediaPlayerPanel.qml 🔴

**Volume button `Item` with bare `width`/`height` inside `RowLayout` (line 228–287):**

```qml
RowLayout {
    Layout.fillWidth: true
    spacing: 4
    ...
    Item {
        id: _volBtn
        width: 40                  // ← bare width inside RowLayout
        height: Style.buttonHeight // ← bare height inside RowLayout
    }
}
```

The RowLayout manages child widths via `implicitWidth` or `Layout.preferredWidth`. Bare `width` on a Layout child is overridden by the layout engine (or at minimum ignored). The volume button may collapse or stretch unexpectedly.

**Fix:**
```qml
Item {
    id: _volBtn
    implicitWidth:  40
    implicitHeight: Style.buttonHeight
}
```

Also: `_marqueeClip` uses `height: Style.buttonHeight` inside the same RowLayout. Fix: `implicitHeight: Style.buttonHeight`.

---

### NotificationPanel.qml ✅

Structure is clean. Body `Item` uses anchors (not inside a Layout — correct). Card RowLayouts inside delegate Rectangles use `anchors { top, left, right, margins }` which is fine since they're the layout root. Overall `implicitHeight` is computed correctly.

Minor note: SysTrayBar is placed via anchors at the bottom — not inside a Layout, which is correct.

---

### SettingsPanel.qml ⚠️

**Issue 1 — filter display Row (line 190–207):**

```qml
Rectangle {
    Row {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter;
                  leftMargin: 8; rightMargin: 8 }
        spacing: 4
        Text { ... anchors.verticalCenter: parent.verticalCenter }   // ← inside positioner
        Text { ... anchors.verticalCenter: parent.verticalCenter }
        Text { ... anchors.verticalCenter: parent.verticalCenter }
    }
}
```

Same pattern as ScrollChip: anchored positioner with anchored children inside it.

**Fix:** Replace `Row` with `RowLayout`:
```qml
RowLayout {
    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter;
              leftMargin: 8; rightMargin: 8 }
    spacing: 4
    Text { ... }
    Text { Layout.fillWidth: true }
    Text { ... }
}
```

**Issue 2 — wallpaper input Rectangle (line 663–693):**

```qml
Rectangle {
    Layout.fillWidth: true
    height: Style.buttonHeight     // ← bare height inside RowLayout
    ...
}
```

**Fix:** `implicitHeight: Style.buttonHeight`.

---

### SysTrayBar.qml ✅

`RowLayout` root with `implicitWidth`/`implicitHeight` set correctly. Fixed-size delegate icons (`width: 24; height: 24`) are fine since SysTrayBar itself is placed via anchors in NotificationPanel, not inside a Layout.

---

### TimerWidget.qml ⚠️

All buttons inside `ColumnLayout { id: layout }` use bare `height:` instead of layout-appropriate sizing:

```qml
ColumnLayout {
    // Row 1
    RowLayout {
        Layout.fillWidth: true
        Rectangle { Layout.fillWidth: true; height: 20 }   // ← bare height
        Rectangle { Layout.fillWidth: true; height: 20 }
    }
    // Row 2
    RowLayout {
        Layout.fillWidth: true
        Rectangle { id: durationBtn; Layout.fillWidth: true; height: 20 }
        Rectangle { Layout.fillWidth: true; height: 20 }
    }
    // Duration input
    Rectangle { Layout.fillWidth: true; height: 28 }      // ← bare height
}
```

**Fix:** Replace all `height: N` with `implicitHeight: N` (or `Layout.preferredHeight: N`) on every direct Layout child.

The clock face `Row { anchors.horizontalCenter/verticalCenter }` inside a plain `Item` is fine — the Item is not a Layout.

---

### WallpaperPanel.qml ⚠️ (minor)

```qml
ColumnLayout {
    Grid {
        columns: 6; spacing: root._spacing
        Layout.fillWidth: true    // ← Grid ignores this
        Repeater { ... }
    }
}
```

`Grid` is a positioner inside a `ColumnLayout`. `Layout.fillWidth: true` on a Grid has no effect — Grid sizes itself from its children. The swatch widths are manually computed from `root.width` (the panel width), so the layout works correctly, but `Layout.fillWidth` is misleading.

The image/video carousels use explicit item positioning for animation — intentional, no fix needed.

**Fix for the Grid:** Remove `Layout.fillWidth: true` (it does nothing). The Grid is already manually sized via `_swatchW` calculation. Alternatively, compute swatch widths from the ColumnLayout's width using a binding once the Layout is standardized.

---

## Fix Priority Order

| Priority | File | Issue | Severity |
|---|---|---|---|
| ~~1~~ | ~~`ControlPanel.qml`~~ | ~~Conflicting `anchors.centerIn` + `anchors.left/right` on network Text~~ | ✅ Fixed |
| ~~2~~ | ~~`MediaPlayerPanel.qml`~~ | ~~`width`/`height` on `_volBtn` and `_marqueeClip` inside RowLayout~~ | ✅ Fixed |
| ~~3~~ | ~~`ControlPanel.qml`~~ | ~~`height: Style.buttonHeight` on network Rectangle inside ColumnLayout~~ | ✅ Fixed |
| ~~4~~ | ~~`TimerWidget.qml`~~ | ~~`height: N` on all ColumnLayout children~~ | ✅ Fixed |
| 5 | `SettingsPanel.qml` | `height: Style.buttonHeight` on wallpaper input Rectangle | ⚠️ |
| 6 | `SettingsPanel.qml` | Filter `Row` with anchors + anchors-inside-positioner children | ⚠️ |
| ~~7~~ | ~~`CalendarPanel.qml`~~ | ~~`anchors.fill` in Flickable (should be left+right+top only)~~ | ✅ Fixed |
| ~~8~~ | ~~`PanelTabBar.qml`~~ | ~~`Row { anchors.fill }` + manual `width / labels.length`~~ | ✅ Fixed |
| ~~9~~ | ~~`ScrollChip.qml`~~ | ~~`Row { anchors { left, right } }` + anchors-in-Row children + `implicitHeight: Style.buttonHeight`~~ | ✅ Fixed |
| ~~10~~ | ~~`SectionHeader.qml`~~ | ~~`anchors.verticalCenter` on items inside `Row`~~ | ✅ Fixed |
| ~~11~~ | ~~`PanelNavBar.qml`~~ | ~~`Row` inside `RowLayout` for dot indicators~~ | ✅ Fixed |
| ~~12~~ | ~~`PanelCard.qml`~~ | ~~`height: childrenRect.height` — fragile with layouts~~ | ✅ Fixed |
| 13 | `WallpaperPanel.qml` | `Layout.fillWidth: true` on `Grid` (no-op) | ⚠️ minor |

---

## Approach

Fix one component at a time, starting with the bugs (1–2), then working through the anti-patterns by component. Test after each component. Step 7 (ControlPanel screenrec section rewrite) must wait until the ControlPanel fixes from this audit are applied first.
