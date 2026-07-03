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
    // Three independently-animated things — pill (bar container), text (the
    // rolling-text transition), panel (expanded calendar/mpris/window content)
    // — run as three strictly sequential, non-overlapping 50ms stages, never
    // two at once (see shell.qml: _pillOpen/_rollProgress+_rollScaleProgress/
    // _panelOpen, and the gating in onActiveModuleChanged/_panelOpenTarget/
    // _readyToHide):
    //   Enter:  Pill (0-50ms)  → Text (50-100ms)  → Panel (100-150ms)
    //   Exit:   Panel (0-50ms) → Text (50-100ms)  → Pill (100-150ms)
    // All three use the same duration and the same enter/exit easing pair —
    // OutQuad (fast start, decelerating) entering, InQuad (slow start,
    // accelerating) exiting — reactively chosen per-direction in shell.qml
    // rather than fixed constants here, so there's a single duration token to
    // bump for slow-motion testing rather than three.
    readonly property int rollDuration:      50  // ms
    readonly property int pillSlideDuration: 50  // ms

    // ── Hot zone (dedicated hover-to-reveal strip, shell.qml) ─────────────────
    // A separate, never-resizing surface above the pill, deliberately
    // decoupled from it — see the `hotZone` PanelWindow in shell.qml for why.
    // hotZoneHeight doubles as the pill's own `margins.top` so the two sit
    // flush with no dead pixel row between them.
    readonly property int  hotZoneHeight:     4     // px
    readonly property real hotZoneWidthFrac:  0.15  // fraction of screen width

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
