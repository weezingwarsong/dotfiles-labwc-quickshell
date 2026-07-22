# Useless Pretty Things — Design Discussion

## Status: In discussion

---

## Context

The **System** section in `ControlPanel.qml` has a collapsible `SectionHeader` ("System", tooltip: "System resource usage") with a 120px placeholder `Rectangle` inside. That placeholder is the reserved canvas for this work.

The section is already wired: `_systemCollapsed: true` (collapsed by default), animated expand/collapse (`Behavior on Layout.preferredHeight`), `_systemRows` ColumnLayout ready to receive content.

---

## What goes here

Pretty, real-time system graphs. CPU, memory, whatever else looks good. Purely cosmetic — the "useless" in the title is intentional. No alerts, no critical path logic, no actionable controls. Just something nice to look at when you open the panel.

---

## Open Questions

- What metrics? CPU usage, RAM, GPU, network throughput, disk I/O, temperatures, ...?
- How many graphs / what layout?
- Style: bars, sparklines, rings, waveforms, ...?
- Data source: read `/proc/` directly from QML, or a background `SystemProcess`?
- Update interval?
- Fixed height or content-driven?
