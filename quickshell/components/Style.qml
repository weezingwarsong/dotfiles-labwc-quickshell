pragma Singleton
import QtQuick

QtObject {
    // ── Font ────────────────────────────────────────────────────────────────
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int    fontSize:   10

    // ── Rectangle: Main (top-level pill in bar) ──────────────────────────────
    readonly property color rectMainBg:     "#E63B4252"   // Nord1 90%
    readonly property color rectMainBorder: "#E64C566A"   // Nord3 90%
    readonly property int   rectBorderWidth: 2

    // ── Rectangle: Main Critical (pill in alert/recording state) ─────────────
    readonly property color rectMainCriticalBg:     "#E6BF616A"   // Nord11 90%
    readonly property color rectMainCriticalBorder: "#E6D08770"   // Nord12 90%

    // ── Rectangle: Normal (expanded panels spawned below the pill) ───────────
    readonly property color rectNormalBg:     "#E62E3440"   // Nord0 90%
    readonly property color rectNormalBorder: "#E63B4252"   // Nord1 90%

    // ── Rectangle: Button (interactive button inside a panel) ────────────────
    readonly property color rectButtonBg:     "#E6434C5E"   // Nord2 90%
    readonly property color rectButtonBorder: "#E64C566A"   // Nord3 90%

    // ── Text: Header (inside the 24px main pill) ─────────────────────────────
    readonly property color textHeaderLow:       "#4C566A"   // Nord3  dimmed / inactive
    readonly property color textHeaderNormal:    "#D8DEE9"   // Nord4  standard label
    readonly property color textHeaderHighlight: "#8FBCBB"   // Nord7  accent / primary info
    readonly property color textHeaderCritical:  "#BF616A"   // Nord11 alert on normal bg

    // ── Text: Body (inside expanded panels) ──────────────────────────────────
    readonly property color textBodyLow:       "#4C566A"   // Nord3  dimmed / disabled
    readonly property color textBodyNormal:    "#D8DEE9"   // Nord4  standard content
    readonly property color textBodyHighlight: "#8FBCBB"   // Nord7  accent / interactive
    readonly property color textBodyCritical:  "#BF616A"   // Nord11 inline alert in panel

    // ── Text: Special ────────────────────────────────────────────────────────
    readonly property color textBright:  "#ECEFF4"   // Nord6  high contrast — use on colored backgrounds
    readonly property color textSuccess: "#A3BE8C"   // Nord14 completion / success state
}
