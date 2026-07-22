# Useless Pretty Things — Design Discussion

## Status: In discussion

---

## Context

The **System** section in `ControlPanel.qml` has a collapsible `SectionHeader` ("System", tooltip: "System resource usage") with a 120px placeholder `Rectangle` inside. That placeholder is the reserved canvas for this work.

The section is already wired: `_systemCollapsed: true` (collapsed by default), animated expand/collapse (`Behavior on Layout.preferredHeight`), `_systemRows` ColumnLayout ready to receive content.

---

## What goes here

Four real-time system graphs in a **2×2 grid**: CPU, MEM, GPU, DISK. Purely cosmetic — no alerts, no actionable controls. Rendered with GLSL shaders via QML `ShaderEffect`. The "useless" in the title is intentional.

---

## Decided

### Layout

2×2 `GridLayout` replacing the placeholder `Rectangle` in `_systemRows`. Fixed cells: top-left CPU, top-right MEM, bottom-left GPU, bottom-right DISK.

Each cell is a perfect square: `height = PanelCard.width / 2` (two columns → each cell width = half the card; height equals width). `Layout.preferredHeight: parent.width / 2` on each cell.

### Metrics & Data Sources

| Metric | Source | Notes |
|---|---|---|
| **CPU** | `/proc/stat` | Diff idle vs total ticks between samples → % |
| **MEM** | `/proc/meminfo` | `(MemTotal − MemAvailable) / MemTotal` → % |
| **GPU** | `/sys/class/drm/card1/device/gpu_busy_percent` | Single-integer sysfs file, no root needed. `card1` on this machine. |
| **DISK** | `/proc/diskstats` — device `nvme0n1` | Diff sectors read+written between samples × 512 bytes → MB/s. Ceiling: **2000 MB/s**. Normalised to 0–1 for shader input. |

All four polled by a single `SystemProcess.qml` root process on a **1-second `Timer`**. No history buffer needed — the orbital animation is driven by the current live value and a continuous `time` uniform, not historical samples.

### Visual concept — Orbital dot

Each cell contains a single `ShaderEffect` filling the square. The track circle is **invisible at runtime** — it exists only as the mathematical path the dot follows.

**Behaviour:**
- A dot travels the circle clockwise. **One full lap = 30 seconds**, driven by a continuous `time` uniform (smooth, not stepped).
- The dot leaves a **trailing arc** behind it, fixed at **25% of circumference** (~90°).
- The trail **wiggles radially** — each point on the trail is displaced inward/outward from the circle path by a sine-based offset, making the tail snake as it trails the dot. Wiggle amplitude and frequency are **loosely tied to the current metric value** — higher load = more agitated trail.
- The trail **tapers**: head = dot size, tail approaches zero width.
- **Dot size** follows the metric % — near-zero at 0%, maximum at 100%.
- **Length breathing** — the dot size oscillates with a **1-second period** (additive sine wave on top of the value-driven size). Causes the dot to pulse at rest.
- All effects — radial wiggle, size, taper, breathing, color — run simultaneously and continuously in the fragment shader.

All 4 metrics use **identical visual treatment** — same shader, same rules, just different `value` input.

### Shader inputs

Passed as uniforms to `orbit.frag.qsb`:

| Uniform | Type | Description |
|---|---|---|
| `value` | `float` | Current metric, 0.0–1.0 |
| `time` | `float` | Continuous elapsed seconds (QML `frameanimation` or `Timer`-accumulated) |
| `successColor` | `vec4` | `Style.textSuccess` |
| `criticalColor` | `vec4` | `Style.textCritical` |

### Color

Continuous HSL interpolation between `successColor` (green, 0%) and `criticalColor` (red, 100%) done in the fragment shader. Lerp on hue only — saturation and lightness held constant. Naturally produces green → yellow-green → yellow → orange → red with no intermediate tokens.

Applies to both dot and trail. Trail fades in opacity toward the tail but keeps the same hue.

GLSL helpers needed: `rgb2hsl()` and `hsl2rgb()` — small inline functions in the shader.

### Cell text overlay

Two QML `Text` items stacked over the `ShaderEffect` via `anchors.fill` + `z` ordering:

- `_valueText` — shows the live integer value (e.g. `"73"`, no % sign). Visible by default.
- `_labelText` — shows the metric name (`"CPU"`, `"MEM"`, `"GPU"`, `"DISK"`). Visible on hover.

On hover: `_valueText` fades out, `_labelText` fades in via `NumberAnimation` on `opacity`. `HoverHandler` drives it. Standard QML — no shader involvement.

Text cannot be passed to GLSL as strings. SDF text in GLSL would require a pre-baked glyph atlas texture and a font renderer in the fragment shader — not worth it here.

### File structure

```
quickshell/
└── module-panels/
    └── system-graphs/
        ├── SystemGraph.qml     ← reusable single-cell component
        ├── orbit.frag          ← GLSL source (edit this)
        ├── orbit.frag.qsb      ← compiled Qt shader binary (load this)
        └── qmldir
```

`ControlPanel.qml` instantiates four `SystemGraph` items in the 2×2 GridLayout, each receiving a `value: float` and `label: string` from `SystemProcess`.

**Shader compile step:** Qt 6 `ShaderEffect` requires compiled `.qsb` files — raw GLSL cannot be loaded directly. When `orbit.frag` changes, recompile:
```bash
qsb --glsl 100es,120,150 -o orbit.frag.qsb orbit.frag
```
Both `.frag` (source) and `.frag.qsb` (binary) live in the repo.

### Derived geometry (normalised shader space — cell width = 1.0)

| Property | Value | Derivation |
|---|---|---|
| Circle radius | `0.4` | 80% of cell diameter, 10% padding each side |
| Oscillation max amplitude | `0.25` | 25% of cell width at 100% load |
| Oscillation min amplitude | `0.0` | No wiggle at 0% load |
| Oscillation scale | `mix(0.0, 0.25, value)` | Linear with value |
| Dot radius max | `0.25` | Diameter = 50% of cell at 100% (intentionally dramatic) |
| Dot radius min | `0.02` | Tiny but visible at 0% |
| Dot radius scale | `mix(0.02, 0.25, value)` | Linear with value |
| Breathing amplitude | `dotRadius × 0.2` | 20% of current dot radius — scales with load |
| Breathing period | `1.0s` | Fixed, sine wave: `sin(time × 2π)` |
| Final dot radius | `dotRadius + breathAmp × sin(time × 2π)` | Value-driven base + breathing on top |

These are normalised values for the GLSL fragment shader. All geometry math lives in the shader; QML only passes `value` (0.0–1.0), `time` (continuous float), `successColor`, and `criticalColor`.

---

## TBD

Nothing blocking. All open questions resolved. Ready to build.
