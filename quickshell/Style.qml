pragma Singleton
import QtQuick

QtObject {
    id: style

    // =========================================================================
    // ─── Variable (Primitives) ───────────────────────────────────────────────
    // =========================================================================

    // ── Colors ──────────────────────────────────────────────────────────────
    // Standard 16-color terminal palette, seeded with Nord.
    // color0      = deepest background
    // color1–3    = dark surfaces and borders (Polar Night)
    // color4–6    = text on dark backgrounds (Snow Storm)
    // color7–10   = frost blues (accents, focus, indicators)
    // color11–15  = aurora (semantic states: critical, success, …)
    readonly property color transparent: "transparent"
    readonly property color color0:  "#2E3440"   // nord0  — background
    readonly property color color1:  "#3B4252"   // nord1  — low surface, faint border
    readonly property color color2:  "#434C5E"   // nord2  — raised surface, button fill
    readonly property color color3:  "#4C566A"   // nord3  — dim border, inactive text
    readonly property color color4:  "#D8DEE9"   // nord4  — secondary text
    readonly property color color5:  "#E5E9F0"   // nord5  — standard body text
    readonly property color color6:  "#ECEFF4"   // nord6  — primary / heading text
    readonly property color color7:  "#8FBCBB"   // nord7  — frost teal (unassigned)
    readonly property color color8:  "#88C0D0"   // nord8  — frost ice-blue, dot indicators
    readonly property color color9:  "#81A1C1"   // nord9  — frost soft-blue, accent text
    readonly property color color10: "#5E81AC"   // nord10 — frost deep-blue, focus / borders
    readonly property color color11: "#BF616A"   // nord11 — aurora red, critical state
    readonly property color color12: "#D08770"   // nord12 — aurora orange (unassigned)
    readonly property color color13: "#EBCB8B"   // nord13 — aurora yellow (unassigned)
    readonly property color color14: "#A3BE8C"   // nord14 — aurora green, success
    readonly property color color15: "#B48EAD"   // nord15 — aurora purple (unassigned)

    // ── Fonts ────────────────────────────────────────────────────────────────
    readonly property string fontMono: Prefs.fontMono   // user-adjustable
    readonly property string fontNerd: Prefs.fontNerd   // user-adjustable
    readonly property string fontCJK:  "Sarasa Mono SC" // constant — not user-adjustable in v1

    // =========================================================================
    // ─── Fixed (Semantic Tokens) ─────────────────────────────────────────────
    // =========================================================================

    // ── Surfaces & Structure ─────────────────────────────────────────────────
    readonly property color pillBgColor:       style.color0
    readonly property color panelBgColor:      style.color0
    readonly property color panelBorderColor:  style.color1
    readonly property color panelDividerColor: style.color2
    readonly property color surfaceLowColor:   style.color1
    readonly property color surfaceMidColor:   style.color2

    // ── Borders ──────────────────────────────────────────────────────────────
    readonly property color borderSoftColor:   style.color3
    readonly property color borderFaintColor:  style.color1
    readonly property color borderAccentColor: style.color10

    // ── Accent ───────────────────────────────────────────────────────────────
    readonly property color accentBgColor:   Qt.darker(style.color10, 2.4)
    readonly property color accentBgHover:   Qt.darker(style.color10, 1.8)
    readonly property color accentColor:     style.color10
    readonly property color criticalBgColor: Qt.darker(style.color11, 2.4)
    readonly property color successBgColor:  Qt.darker(style.color14, 2.4)

    // ── Text ─────────────────────────────────────────────────────────────────
    readonly property color textPrimary:   style.color6   // headings, pill text
    readonly property color textNormal:    style.color5   // standard body
    readonly property color textSecondary: style.color4   // secondary content, labels
    readonly property color textMuted:     style.color4   // de-emphasised / timestamps
    readonly property color textFaint:     style.color2   // barely-visible anchors
    readonly property color textAccent:    style.color9   // accent links, highlighted text
    readonly property color textCritical:  style.color11  // error / alert
    readonly property color textSuccess:   style.color14  // completion / positive
    readonly property color textWeekend:   style.color10  // calendar weekend day numbers
    readonly property color dotIndicator:  style.color8   // calendar event dot markers

    // ── Layout constants ──────────────────────────────────────────────────────
    readonly property int buttonHeight: 22
    readonly property int panelMargin:  12

    // =========================================================================
    // ─── Prefs-derived (user-adjustable) ─────────────────────────────────────
    // =========================================================================

    // ── Typography ───────────────────────────────────────────────────────────
    readonly property int fontSizePill:    Prefs.fontSizePill         // pill text — independent
    readonly property int fontSizeHeading: Prefs.fontSizeBase + 2     // panel section headers
    readonly property int fontSizeBody:    Prefs.fontSizeBase         // standard panel content
    readonly property int fontSizeSubtle:  Prefs.fontSizeBase - 1     // smallest panel text

    // ── Radius (scale-driven) ────────────────────────────────────────────────
    readonly property real radSm: Math.round(4  * Prefs.radiusScale)  // buttons, small elements
    readonly property real radMd: Math.round(6  * Prefs.radiusScale)  // cards, tooltips
    readonly property real radLg: Math.round(10 * Prefs.radiusScale)  // pills, panels

    // ── Border widths ────────────────────────────────────────────────────────
    readonly property int borderWidth:        Prefs.borderWidth         // pill + panel containers
    readonly property int elementBorderWidth: Prefs.elementBorderWidth  // buttons, inputs
}
