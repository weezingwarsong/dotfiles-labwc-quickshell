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

    // ── Animation ─────────────────────────────────────────────────────────────
    // Used by the rolling-text transition in shell.qml.  The bar itself is a
    // rigid rectangle that never moves; when the active module changes, the
    // outgoing content rolls out (translate + squash toward the edge it exits
    // through) while the incoming content rolls in (translate + squash from 0)
    // — as if content were printed on a cylinder rotating behind the bar's
    // clipped window.  Direction is determined by comparing _modPriority
    // indices: higher priority rolls in from the bottom.
    readonly property int rollDuration:        350  // ms; bump to 1000 for slow-motion testing
    readonly property int rollTranslateEasing: Easing.InOutCubic
    readonly property int rollScaleEasing:     Easing.InOutQuad

    // ── Pill show/hide (hidden by default, slides out on demand) ─────────────
    // The slide plays only after the roll transition above has already
    // settled the content back on "time" — see _readyToHide in shell.qml.
    readonly property int pillSlideDuration: 300  // ms
    readonly property int pillSlideEasing:   Easing.InOutCubic
    readonly property int hotZoneHeight:     6    // px — always-alive hover strip when retracted

    // ── Fetch intervals (periodic Process polling in shell.qml) ──────────────
    // Separate tokens even though both default to 5 min, so either can be
    // tuned independently later without touching the other.
    readonly property int calendarFetchIntervalMs: 5 * 60 * 1000
    readonly property int weatherFetchIntervalMs:  5 * 60 * 1000

    // ── Pill (the always-visible 24 px bar element) ───────────────────────────
    // These are the SHIPPED DEFAULTS — a future settings panel writes user
    // overrides (color/opacity/radius) to a separate document and layers them
    // on top rather than mutating this file; this stays the "reset" baseline.
    readonly property int   pillHeight: 24
    readonly property int   pillRadius: 0  // sharp rectangle, not a capsule
    readonly property real  pillOpacity: 0.9
    readonly property color pillBg:         Qt.rgba(nord0.r, nord0.g, nord0.b, pillOpacity)
    readonly property color pillBorder:     Qt.rgba(nord3.r, nord3.g, nord3.b, pillOpacity)
    readonly property int   pillBorderWidth: 2

    // ── Pill: Critical variant (recording / alert state) ─────────────────────
    readonly property color pillCriticalBg:     Qt.rgba(nord11.r, nord11.g, nord11.b, pillOpacity)
    readonly property color pillCriticalBorder: Qt.rgba(nord12.r, nord12.g, nord12.b, pillOpacity)

    // ── Panel (spawned below the pill on demand or hover) ─────────────────────
    readonly property int   panelRadius: 0
    readonly property real  panelOpacity: 0.9
    readonly property color panelBg:         Qt.rgba(nord0.r, nord0.g, nord0.b, panelOpacity)
    readonly property color panelBorder:     Qt.rgba(nord3.r, nord3.g, nord3.b, panelOpacity)
    readonly property int   panelBorderWidth: 2

    // ── Panel: Button (interactive element inside a panel) ────────────────────
    readonly property int   panelButtonRadius: 0
    readonly property real  panelButtonOpacity: 0.9
    readonly property color panelButtonBg:         Qt.rgba(nord2.r, nord2.g, nord2.b, panelButtonOpacity)
    readonly property color panelButtonBorder:     Qt.rgba(nord3.r, nord3.g, nord3.b, panelButtonOpacity)
    readonly property int   panelButtonBorderWidth: 2

    // ── Panel: Button shadow (hover-grow drop shadow shared by every panel
    //    button — PinButton, PanelIconButton, Mpris focus button, Time's
    //    month/year + day-cell buttons). Centralized to kill duplicated
    //    literals; not exposed in the future settings panel. ───────────────────
    readonly property color panelButtonShadowColor:              nord0
    readonly property real  panelButtonShadowBlurRest:            0.25
    readonly property real  panelButtonShadowBlurHover:           0.55
    readonly property int   panelButtonShadowVerticalOffsetRest:  2
    readonly property int   panelButtonShadowVerticalOffsetHover: 6
    readonly property real  panelButtonShadowOpacityRest:         0.5
    readonly property real  panelButtonShadowOpacityHover:        0.8

    // ── Tooltip (Nord-styled hover tooltip inside panels) ─────────────────────
    readonly property int   tooltipRadius: 0
    readonly property real  tooltipOpacity: 0.9
    readonly property color tooltipBg:         Qt.rgba(nord0.r, nord0.g, nord0.b, tooltipOpacity)
    readonly property color tooltipBorder:     Qt.rgba(nord3.r, nord3.g, nord3.b, tooltipOpacity)
    readonly property int   tooltipBorderWidth: 2

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
