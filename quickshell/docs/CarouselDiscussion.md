# Carousel — Design Discussion

Work backward: look → need → implement.

---

## Phase 1 — How it looks and behaves

### Target design

**Container**

The carousel sits inside a `PanelCard`, alongside a `SectionHeader`. All items fit within the card — no horizontal scrolling, no clipping.

**Three size tiers**

There are exactly three discrete sizes, driven by `dist = index − currentIndex` and the current scroll direction:

| Tier | When |
|---|---|
| HERO | `dist = 0` — the selected item |
| NEAR | `\|dist\| = 1` on the upcoming side only |
| SMALL | everything else — all behind items (any dist), and upcoming items at `\|dist\| ≥ 2` |

Width and height both scale with tier — HERO is the tallest and widest, NEAR is intermediate, SMALL is the minimum.

**Directional asymmetry**

The carousel is direction-aware. The upcoming side (the direction you are scrolling toward) shows NEAR for the immediate neighbor. The behind side (where you came from) is flat SMALL regardless of distance.

Scrolling right: right = upcoming, left = behind.
Scrolling left: left = upcoming, right = behind.

The two directions are perfect mirrors of each other.

**Visible window — always 4 items**

At most 4 items are visible at any time (or all items if the list has fewer than 4). The 4 slots are always:

```
1 × HERO  +  1 × NEAR (if upcoming exists)  +  2 × SMALL
```

The SMALL slots fill **behind items nearest-first** (dist=−1, then −2, …). If behind items run out before filling both SMALL slots, the remaining SMALL slots take further upcoming items (dist=+2, +3, …). When no upcoming item exists (hero at list edge), the NEAR slot is absent — HERO's `fillWidth` expands to fill the gap, and the 2 SMALL slots take the nearest behind items.

Any slot that has no image to show (out of list bounds) is simply hidden (`visible: false`). No placeholder is rendered — the HERO stretches to fill whatever space was vacated.

Example — 5 images, scrolling right (`_direction = +1`):

| Hero | NEAR | SMALL ×2 | Hidden |
|---|---|---|---|
| img1 | img2 | img3 + img4 (no behind → take ahead) | img5 |
| img2 | img3 | img1 (behind) + img4 (ahead) | img5 |
| img3 | img4 | img2 + img1 (both behind) | img5 |
| img4 | img5 | img3 + img2 (both behind) | img1 |
| img5 | — | img4 + img3 (both behind) | img2, img1 |

**Width and height sizing**

Widths are expressed as fractions of the row width (`rowW`):

- **NEAR**: `nearW = rowW × 0.20`, portrait 9:16 ratio → `nearH = nearW × 16/9`
- **SMALL**: `smallW = nearW / 2 = rowW × 0.10`, same height as NEAR → `smallH = nearH`
- **HERO**: `Layout.fillWidth: true` (takes all remaining space), `heroH = nearH × 1.02`

The RowLayout engine handles the math:

```
heroW = rowW − nearW − 2×smallW − gaps  ≈  rowW × 0.60  (minus gaps)
```

With fewer items in the list, fewer fixed-width slots exist and HERO simply grows wider — no special cases needed:

| Count | Visible items | Hero gets |
|---|---|---|
| 1 | HERO only | 100% of row |
| 2 | HERO + 1 NEAR | row − nearW − gaps |
| 3 | HERO + 1 NEAR + 1 SMALL | row − nearW − smallW − gaps |
| 4+ | HERO + 1 NEAR + 2 SMALL | row − nearW − 2×smallW − gaps |

The RowLayout's `implicitHeight` = `heroH`. NEAR and SMALL are shorter and sit vertically centered (`Layout.alignment: Qt.AlignVCenter`).

**Image rendering — clipping viewport**

Each container is a clipping window into its wallpaper image. The image is scaled so its **width equals the full row width** — it spans from the left edge to the right edge of the RowLayout (not the PanelCard). Height follows from the aspect ratio, which typically causes the image to bleed above and below the row. The image is **vertically centered** within the row.

This means all containers share a single coordinate space per image:
- Horizontally: a container at row-position `xPos` sees the image strip from `xPos` to `xPos + containerWidth`.
- Vertically: each container sees the vertical center of the image, clipped to its own height.

The image `x` offset inside the container is `-xPos`. The image `y` offset is `-(imageHeight - containerHeight) / 2`, centering it within the container's clip region.

As containers animate (e.g., HERO → NEAR), their size and row position both change, so the visible strip shifts automatically — no separate panning logic needed.

Implementation: `clip: true` on the container `Rectangle`, `Image` inside with `width: rowWidth`, `fillMode: Image.Pad`, `x: -container.x`, `y: -(height - parent.height) / 2`.

**Edge pinning**

When the hero is at the first or last index, it sits flush against the corresponding card wall. This is a natural consequence of the fill constraint, not a special case.

**Spacing**

RowLayout `spacing: 4`. To be wired to a Style token later.

**Rounded corners**

None for this iteration. Can be added later.

**Active indicator**

HERO slot has a 2px accent-colored border (`Rectangle` overlay, transparent fill). NEAR and SMALL have no border. Can be changed later.

**Filename label**

Deferred — not part of this design iteration.

**Animation**

When `currentIndex` changes, slot roles reassign immediately. The width and height changes animate via `Behavior { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }` on each slot's `Layout.preferredWidth` and `Layout.preferredHeight`. As slots animate their sizes, `slot.x` (managed by the RowLayout engine) updates automatically, which drives the image viewport pan for free.

No `_scrollPos` property needed. Slots that enter or leave the visible window snap in/out (`visible` change is instant — no entry/exit animation for this iteration).

**Direction state**

A `_direction: int` property (`+1` = right, `−1` = left) is updated on each scroll step. It determines which signed side of `dist` maps to NEAR vs flat SMALL.

---

## Phase 2 — What we need

**Carousel.qml** as a reusable element (`module-reusable-elements/`). Root is a `RowLayout`.

**Properties (in/out)**

| Property | Type | Direction | Description |
|---|---|---|---|
| `model` | `var` (list of `{path, name}` objects) | in | Files to display |
| `currentIndex` | `int` | in + out | Which item is HERO. Caller sets it once (imperatively, not as a binding) to initialize; Carousel writes to it on every scroll step. Do not bind this from the outside. |
| `emptyText` | `string` | in | Message shown centered when `model` is empty |

**Signals (out)**

| Signal | Description |
|---|---|
| `activated(int index)` | Emitted when the user scrolls or clicks — caller decides what to do (e.g. set wallpaper) |

**Internal state**

| Property | Type | Description |
|---|---|---|
| `_direction` | `int` | `+1` = scrolled right, `−1` = scrolled left |

**Sizing constants (on root RowLayout)**

```
_nearW  = root.width × 0.20
_smallW = _nearW / 2
_nearH  = _nearW × 16/9
_heroH  = _nearH × 1.02
_heroW  = root.width − (NEAR_count × _nearW) − (SMALL_count × _smallW) − spacing × (NEAR_count + SMALL_count)
```

HERO does **not** use `Layout.fillWidth`. `_heroW` is computed explicitly so all three tiers animate through a `Behavior on Layout.preferredWidth`. This ensures a smooth transition when a slot enters or leaves the HERO role.

**Window object (computed property on root)**

```js
_window = {
  hero:   currentIndex,          // always valid
  near:   nearIdx or -1,         // -1 when at list edge
  smalls: [idx, idx]             // 0–2 entries
}

// Fill order:
//   1. behind nearest-first: currentIndex − _direction×1, ×2, …
//   2. further upcoming if behind runs out: currentIndex + _direction×2, ×3, …
```

**Layout stack**

```
Carousel (RowLayout)
  id: root
  spacing: 4
  implicitHeight: _heroH

  Text (empty state)
    visible: model.length === 0
    text:    emptyText
    Layout.fillWidth: true
    Layout.preferredHeight: _heroH
    horizontalAlignment / verticalAlignment: Center

  Repeater { model: root.model }
    delegate: Rectangle (slot)
      clip: true
      color: "transparent"
      visible: _isHero || _isNear || _isSmall   ← false removes from RowLayout flow

      readonly _isHero:  index === _window.hero
      readonly _isNear:  index === _window.near
      readonly _isSmall: _window.smalls.indexOf(index) !== -1

      Layout.alignment:     Qt.AlignVCenter
      Layout.preferredWidth:  _isHero ? _heroW : _isNear ? _nearW : _smallW
      Layout.preferredHeight: _isHero ? _heroH : _nearH
      Behavior on Layout.preferredWidth  { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      Image
        source:   "file://" + modelData.path
        width:    root.width
        height:   implicitWidth > 0 ? width × (implicitHeight / implicitWidth) : _heroH
        x:        -slot.x          ← viewport offset into the full-row image
        y:        -(height - slot.height) / 2
        fillMode: Image.Pad
        asynchronous: true

      Rectangle (border)
        anchors.fill: parent
        color: "transparent"
        border.width: _isHero ? 2 : 0
        border.color: Style.accentColor

      TapHandler
        onTapped: {
            _direction   = index > currentIndex ? 1 : -1
            currentIndex = index
            root.activated(index)
        }

  WheelHandler
    onWheel: {
        dir          = angleDelta.y < 0 ? 1 : -1
        next         = clamp(currentIndex + dir, 0, count-1)
        _direction   = dir
        currentIndex = next
        root.activated(next)
    }
```

**What the carousel does NOT do**

- Does not call `setImage` / `setVideo` — that is the caller's job via `activated(index)`
- Does not know about wallpaper processes
- Does not own a filename label (deferred)

**Reference sketch**

`docs/screenshot_2026-07-18_20-43-18.png` — hand-drawn viewport model showing:
- Top-left (red): full wallpaper image with HERO and NEAR container viewports overlaid, demonstrating that the image spans the full row width and each container clips its positional strip
- Top-right (green): 4-slot layout (HERO con1, NEAR con2, SMALL con3, SMALL con4) with each container's own image
- Bottom-left (red): "CON2 IS NOW HERO" — con1 shrinks to SMALL, con2 grows to HERO; image content shifts accordingly
- Bottom-right (green): same transition from the second image set

---

## Phase 3 — How to implement

**Step 1 — Create `module-reusable-elements/Carousel.qml`**

New file. Root is `RowLayout`. See Phase 2 layout stack for the full tree.

**Step 2 — Register in `module-reusable-elements/qmldir`**

Add: `Carousel 1.0 Carousel.qml`

**Step 3 — Replace `_imageTab` in `WallpaperPanel.qml`**

See `docs/WallpaperPanelImageDiscussion.md` Phase 3 for the WallpaperPanel side.

**Step 4 — Test**

- Toggle wallpaper panel → image tab visible → carousel snaps to active wallpaper
- Scroll left/right → images animate, active border follows
- Scroll to list edges → NEAR disappears, HERO grows wider
- 1/2/3 image lists → verify HERO fills correctly
- Empty dir / no dir → emptyText shows
- Restart quickshell → active wallpaper restored correctly
