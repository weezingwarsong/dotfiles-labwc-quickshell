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

    // ── Shared ───────────────────────────────────────────────────────────────
    readonly property int borderWidth: 2

    // ── Animation ─────────────────────────────────────────────────────────────
    // Used by the squish push transition in shell.qml.  When the active module
    // changes, the outgoing content squishes toward its exit edge while the
    // incoming content grows in from the opposite edge.  Direction is determined
    // by comparing _modPriority indices: higher priority enters from the right.
    readonly property int transitionDuration: 350  // ms; bump to 1000 for slow-motion testing
    readonly property int transitionEasing:   Easing.OutCubic

    // ── Pill (the always-visible 24 px bar element) ───────────────────────────
    readonly property int   pillHeight: 24
    readonly property color pillBg:     Qt.rgba(nord1.r, nord1.g, nord1.b, 0.9)
    readonly property color pillBorder: Qt.rgba(nord3.r, nord3.g, nord3.b, 0.9)

    // ── Pill: Critical variant (recording / alert state) ─────────────────────
    readonly property color pillCriticalBg:     Qt.rgba(nord11.r, nord11.g, nord11.b, 0.9)
    readonly property color pillCriticalBorder: Qt.rgba(nord12.r, nord12.g, nord12.b, 0.9)

    // ── Panel (spawned below the pill on demand or hover) ─────────────────────
    readonly property color panelBg:     Qt.rgba(nord0.r, nord0.g, nord0.b, 0.9)
    readonly property color panelBorder: Qt.rgba(nord1.r, nord1.g, nord1.b, 0.9)

    // ── Panel: Button (interactive element inside a panel) ────────────────────
    readonly property color panelButtonBg:     Qt.rgba(nord2.r, nord2.g, nord2.b, 0.9)
    readonly property color panelButtonBorder: Qt.rgba(nord3.r, nord3.g, nord3.b, 0.9)

    // ── Text: Pill ────────────────────────────────────────────────────────────
    readonly property color textPillLow:       nord3   // dimmed / inactive
    readonly property color textPillNormal:    nord4   // standard label
    readonly property color textPillHighlight: nord7   // accent / primary info
    readonly property color textPillCritical:  nord11  // alert on normal bg

    // ── Text: Panel ───────────────────────────────────────────────────────────
    readonly property color textPanelLow:         nord3   // dimmed / disabled
    readonly property color textPanelNormal:      nord4   // standard content
    readonly property color textPanelHighlight:   nord7   // accent / interactive
    readonly property color textPanelCritical:    nord11  // inline alert in panel
    readonly property color textPanelOnHighlight: nord0   // text on a highlighted row

    // ── Text: Panel glyphs (Nerd Font icons) ──────────────────────────────────
    readonly property color textPanelGlyphNormal:      nord7  // icon at rest
    readonly property color textPanelGlyphOnHighlight: nord0  // icon on selected row

    // ── Text: Special ─────────────────────────────────────────────────────────
    readonly property color textBright:  nord6   // high contrast — use on coloured backgrounds
    readonly property color textSuccess: nord14  // completion / success state
}
