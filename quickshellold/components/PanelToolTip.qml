import QtQuick
import QtQuick.Controls

// Shared Nord-themed tooltip for panel content (day-cell events, elided
// agenda text, button hints). Instantiate directly as a child of the
// hoverable item and drive `visible`/`text` yourself — the built-in
// `ToolTip.visible`/`.text` attached-property mechanism looks tempting for
// reuse, but its `ToolTip.toolTip` sub-property (the only hook for
// restyling the popup it creates) is read-only, so it can't be pointed at
// a custom-styled delegate. Positioned just below the hovered item.
ToolTip {
    id: root
    delay: 300
    x: 0
    y: parent ? parent.height + 4 : 0

    // Text.implicitWidth is circular once wrapMode is active (Qt Quick
    // docs warn against binding width to implicitWidth in that case) — this
    // separate, never-wrapped TextMetrics measures the natural width so the
    // wrapped contentItem below can cap at it without a binding loop.
    TextMetrics {
        id: metrics
        font.family: Style.fontFamily
        font.pointSize: Style.fontSize
        text: root.text
    }

    contentItem: Text {
        text: root.text
        color: Style.textPanelNormal
        font.family: Style.fontFamily
        font.pointSize: Style.fontSize
        // Capped and wrapped rather than one long unbroken line — a long
        // event title otherwise stretches the tooltip far enough to spill
        // out over neighboring panel content.
        wrapMode: Text.Wrap
        width: Math.min(metrics.boundingRect.width, 220)
    }

    background: Rectangle {
        color: Style.tooltipBg
        radius: Style.tooltipRadius
        border.width: Style.tooltipBorderWidth
        border.color: Style.tooltipBorder
    }
}
