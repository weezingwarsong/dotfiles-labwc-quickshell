pragma Singleton
import QtQuick

QtObject {
    id: style

    // =========================================================================
    // ─── Variable Preference (Primitives/Tokens) ─────────────────────────────
    // =========================================================================

    // ── Colors ──────────────────────────────────────────────────────────────
    // Nord Snow Storm → mid interpolation → Nord Polar Night (light to dark)
    readonly property color transparent: "transparent"
    readonly property color color0:      "#ECEFF4"   // nord6  — absolute light
    readonly property color color1:      "#E5E9F0"   // nord5  — high contrast text
    readonly property color color2:      "#D8DEE9"   // nord4  — grid content
    readonly property color color3:      "#AEBACF"   //          secondary icons
    readonly property color color4:      "#8291A8"   //          muted context
    readonly property color color5:      "#677080"   //          button static
    readonly property color color6:      "#556070"   //          sub-labels / timestamps
    readonly property color color7:      "#4C566A"   // nord3  — dim anchors
    readonly property color color8:      "#434C5E"   // nord2  — borders / empty state
    readonly property color color9:      "#3E4757"   //          element outlines
    readonly property color color10:     "#3B4252"   // nord1  — low-contrast lines
    readonly property color color11:     "#384050"   //          component dividers
    readonly property color color12:     "#353D4C"   //          rule separators
    readonly property color color13:     "#323A49"   //          structural surface low
    readonly property color color14:     "#2F3644"   //          structural base panel
    readonly property color color15:     "#2E3440"   // nord0  — deep slate background

    // ── Accent Palette ───────────────────────────────────────────────────────
    // Nord Frost blues, dark to light
    readonly property color accent0:     "#253344"   //          active button fill
    readonly property color accent1:     "#2E3F55"   //          active button hover
    readonly property color accent2:     "#5E81AC"   // nord10 — focus core blue
    readonly property color accent3:     "#4A6080"   //          deep steel / weekend
    readonly property color accent4:     "#81A1C1"   // nord9  — active text high-contrast
    readonly property color accent5:     "#88C0D0"   // nord8  — soft light-blue / indicators

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

    readonly property real radShell:     12
    readonly property real radToday:      8
    readonly property real radTooltip:    6
    readonly property real radBtn:        5
    readonly property real radBtnSm:      4


    // =========================================================================
    // ─── Fixed (Component Semantic Mapping) ──────────────────────────────────
    // =========================================================================

    // ── Pill ─────────────────────────────────────────────────────────────────
    readonly property color  pillBgColor:      style.color15
    readonly property real   pillBorderRadius: style.radShell
    readonly property string pillFontMono:     style.fontMono
    readonly property string pillFontNerd:     style.fontNerd
    readonly property int    pillTextSize:     style.sizeLg
    readonly property color  pillTextColor:    style.color0

    // ── Panel Shell ──────────────────────────────────────────────────────────
    readonly property color panelBgColor:      style.color14
    readonly property color panelBorderColor:  style.color11
    readonly property real  panelBorderRadius: style.radShell
    readonly property color panelDividerColor: style.color12

    // ── Intermediary Surfaces / Buttons ──────────────────────────────────────
    readonly property color surfaceLowColor:   style.color13
    readonly property color surfaceMidColor:   style.color11
    readonly property color borderSoftColor:   style.color9
    readonly property color borderFaintColor:  style.color10

    readonly property color accentBgColor:     style.accent0
    readonly property color accentBgHover:     style.accent1
    readonly property color borderAccentColor: style.accent2
    readonly property color textAccentColor:   style.accent4

    // ── Component Specific Radii ─────────────────────────────────────────────
    readonly property real radButton:          style.radBtn
    readonly property real radButtonSmall:     style.radBtnSm
    readonly property real radGridToday:       style.radToday
    readonly property real radGridTooltip:     style.radTooltip

    // ── Tooltips ─────────────────────────────────────────────────────────────
    readonly property color tooltipBorder:     style.color8
    readonly property color tooltipTextSoft:   style.color3

    // ── Typography Scale ─────────────────────────────────────────────────────
    readonly property int fontTimerSize:       style.sizeXl
    readonly property int fontWeatherIcon:     style.sizeLg
    readonly property int fontHeaderSize:      style.sizeMd
    readonly property int fontNavSize:         style.sizeSm
    readonly property int fontContentSize:     style.sizeXs
    readonly property int fontGridNumSize:     style.sizeXxs
    readonly property int fontLabelSize:       style.sizeLabel

    // ── Content Color Map ────────────────────────────────────────────────────
    readonly property color textPrimary:       style.color0
    readonly property color textNormal:        style.color1
    readonly property color textLight:         style.color2
    readonly property color textMuted:         style.color4
    readonly property color textButton:        style.color5
    readonly property color textSubtle:        style.color6
    readonly property color textDim:           style.color7
    readonly property color textFaint:         style.color8
    readonly property color textWeekend:       style.accent3
    readonly property color dotIndicator:      style.accent5
}
