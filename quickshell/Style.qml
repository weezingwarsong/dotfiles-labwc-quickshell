pragma Singleton
import QtQuick

QtObject {
    id: style

    // =========================================================================
    // ─── Variable Preference (Primitives/Tokens) ─────────────────────────────
    // =========================================================================

    // ── Colors ──────────────────────────────────────────────────────────────
    // Standard 16-color terminal palette, seeded with Nord.
    // Future: extracted from the active wallpaper (pywal / matugen format).
    // color0  = deepest background
    // color1–3  = dark surfaces and borders (Polar Night)
    // color4–6  = text on dark backgrounds (Snow Storm)
    // color7–10 = frost blues (accents, focus, indicators)
    // color11–15 = aurora (semantic states: critical, success, …)
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
    readonly property string fontMono:   "JetBrainsMono Nerd Font"
    readonly property string fontNerd:   "JetBrainsMono Nerd Font"

    readonly property int sizeXl:        22
    readonly property int sizeLg:        13
    readonly property int sizeMd:        12
    readonly property int sizeSm:        11
    readonly property int sizeXs:        10
    readonly property int sizeXxs:        9
    readonly property int sizeLabel:      8

    // ── Borders & Radii ──────────────────────────────────────────────────────
    readonly property real borderNone:   0
    readonly property real borderThin:   1
    readonly property real borderThick:  2

    readonly property real radNone:      0
    readonly property real radLight:     4
    readonly property real radMed:       6
    readonly property real radHigh:     10


    // =========================================================================
    // ─── Fixed (Component Semantic Mapping) ──────────────────────────────────
    // =========================================================================

    // ── Pill ─────────────────────────────────────────────────────────────────
    readonly property color  pillBgColor:      style.color0
    readonly property real   pillBorderRadius: style.radHigh
    readonly property string pillFontMono:     style.fontMono
    readonly property string pillFontNerd:     style.fontNerd
    readonly property int    pillTextSize:     style.sizeLg
    readonly property color  pillTextColor:    style.color6

    // ── Panel Shell ──────────────────────────────────────────────────────────
    readonly property color panelBgColor:      style.color0
    readonly property color panelBorderColor:  style.color1
    readonly property real  panelBorderRadius: style.radHigh
    readonly property color panelDividerColor: style.color2

    // ── Intermediary Surfaces / Buttons ──────────────────────────────────────
    readonly property color surfaceLowColor:   style.color1
    readonly property color surfaceMidColor:   style.color2
    readonly property color borderSoftColor:   style.color3
    readonly property color borderFaintColor:  style.color1

    readonly property color accentBgColor:     Qt.darker(style.color10, 2.4)
    readonly property color accentBgHover:     Qt.darker(style.color10, 1.8)
    readonly property color borderAccentColor: style.color10
    readonly property color textAccentColor:   style.color9

    // ── Component Specific Radii ─────────────────────────────────────────────
    readonly property real radButton:          style.radLight
    readonly property real radButtonSmall:     style.radLight
    readonly property real radGridToday:       style.radMed
    readonly property real radGridTooltip:     style.radMed

    // ── Tooltips ─────────────────────────────────────────────────────────────
    readonly property color tooltipBorder:     style.color2
    readonly property color tooltipTextSoft:   style.color4

    // ── Typography Scale ─────────────────────────────────────────────────────
    readonly property int fontTimerSize:       style.sizeXl
    readonly property int fontWeatherIcon:     style.sizeLg
    readonly property int fontHeaderSize:      style.sizeMd
    readonly property int fontNavSize:         style.sizeSm
    readonly property int fontContentSize:     style.sizeXs
    readonly property int fontGridNumSize:     style.sizeXxs
    readonly property int fontLabelSize:       style.sizeLabel

    // ── Content Color Map ────────────────────────────────────────────────────
    readonly property color textPrimary:       style.color6   // headings, pill text
    readonly property color textNormal:        style.color5   // standard body
    readonly property color textLight:         style.color4   // secondary body
    readonly property color textMuted:         style.color4   // de-emphasised content
    readonly property color textButton:        style.color4   // labels on dark button bg
    readonly property color textSubtle:        style.color3   // timestamps, sub-labels
    readonly property color textDim:           style.color3   // inactive / placeholder
    readonly property color textFaint:         style.color2   // barely-visible anchors
    readonly property color textWeekend:       style.color10  // weekend day numbers
    readonly property color dotIndicator:      style.color8   // calendar dot markers
    readonly property color textCritical:      style.color11  // error / alert text
    readonly property color textSuccess:       style.color14  // completion / positive
}
