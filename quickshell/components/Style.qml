pragma Singleton
import QtQuick

QtObject {
    // ── Nord palette ─────────────────────────────────────────────────────────
    // Polar Night
    readonly property color nord0:  "#2E3440"
    readonly property color nord1:  "#3B4252"
    readonly property color nord2:  "#434C5E"
    readonly property color nord3:  "#4C566A"
    // Snow Storm
    readonly property color nord4:  "#D8DEE9"
    readonly property color nord5:  "#E5E9F0"
    readonly property color nord6:  "#ECEFF4"
    // Frost
    readonly property color nord7:  "#8FBCBB"
    readonly property color nord8:  "#88C0D0"
    readonly property color nord9:  "#81A1C1"
    readonly property color nord10: "#5E81AC"
    // Aurora
    readonly property color nord11: "#BF616A"
    readonly property color nord12: "#D08770"
    readonly property color nord13: "#EBCB8B"
    readonly property color nord14: "#A3BE8C"
    readonly property color nord15: "#B48EAD"

    // ── Font ─────────────────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int    fontSize:   10

    // ── Rectangle: Main (top-level pill in bar) ───────────────────────────────
    readonly property color rectMainBg:     Qt.rgba(nord1.r, nord1.g, nord1.b, 0.9)
    readonly property color rectMainBorder: Qt.rgba(nord3.r, nord3.g, nord3.b, 0.9)
    readonly property int   rectBorderWidth: 2

    // ── Rectangle: Main Critical (pill in alert/recording state) ──────────────
    readonly property color rectMainCriticalBg:     Qt.rgba(nord11.r, nord11.g, nord11.b, 0.9)
    readonly property color rectMainCriticalBorder: Qt.rgba(nord12.r, nord12.g, nord12.b, 0.9)

    // ── Rectangle: Normal (expanded panels spawned below the pill) ────────────
    readonly property color rectNormalBg:     Qt.rgba(nord0.r, nord0.g, nord0.b, 0.9)
    readonly property color rectNormalBorder: Qt.rgba(nord1.r, nord1.g, nord1.b, 0.9)

    // ── Rectangle: Button (interactive button inside a panel) ─────────────────
    readonly property color rectButtonBg:     Qt.rgba(nord2.r, nord2.g, nord2.b, 0.9)
    readonly property color rectButtonBorder: Qt.rgba(nord3.r, nord3.g, nord3.b, 0.9)

    // ── Text: Header (inside the 24px main pill) ──────────────────────────────
    readonly property color textHeaderLow:       nord3   // dimmed / inactive
    readonly property color textHeaderNormal:    nord4   // standard label
    readonly property color textHeaderHighlight: nord7   // accent / primary info
    readonly property color textHeaderCritical:  nord11  // alert on normal bg

    // ── Text: Body (inside expanded panels) ───────────────────────────────────
    readonly property color textBodyLow:         nord3   // dimmed / disabled
    readonly property color textBodyNormal:      nord4   // standard content
    readonly property color textBodyHighlight:   nord7   // accent / interactive / selection background
    readonly property color textBodyCritical:    nord11  // inline alert in panel
    readonly property color textOnHighlight:     nord0   // text on a nord7 highlighted background

    // ── Text: Special ─────────────────────────────────────────────────────────
    readonly property color textBright:  nord6   // high contrast — use on colored backgrounds
    readonly property color textSuccess: nord14  // completion / success state
}
