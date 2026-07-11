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
    // Each slot falls back to its Nord default when no override is set.
    // Overrides are written by WallpaperProcess via matugen (base16 mapping).
    readonly property color transparent: "transparent"
    readonly property color color0:  Prefs.color0Override  !== "" ? Prefs.color0Override  : "#2E3440"
    readonly property color color1:  Prefs.color1Override  !== "" ? Prefs.color1Override  : "#3B4252"
    readonly property color color2:  Prefs.color2Override  !== "" ? Prefs.color2Override  : "#434C5E"
    readonly property color color3:  Prefs.color3Override  !== "" ? Prefs.color3Override  : "#4C566A"
    readonly property color color4:  Prefs.color4Override  !== "" ? Prefs.color4Override  : "#D8DEE9"
    readonly property color color5:  Prefs.color5Override  !== "" ? Prefs.color5Override  : "#E5E9F0"
    readonly property color color6:  Prefs.color6Override  !== "" ? Prefs.color6Override  : "#ECEFF4"
    readonly property color color7:  Prefs.color7Override  !== "" ? Prefs.color7Override  : "#8FBCBB"
    readonly property color color8:  Prefs.color8Override  !== "" ? Prefs.color8Override  : "#88C0D0"
    readonly property color color9:  Prefs.color9Override  !== "" ? Prefs.color9Override  : "#81A1C1"
    readonly property color color10: Prefs.color10Override !== "" ? Prefs.color10Override : "#5E81AC"
    readonly property color color11: Prefs.color11Override !== "" ? Prefs.color11Override : "#BF616A"
    readonly property color color12: Prefs.color12Override !== "" ? Prefs.color12Override : "#D08770"
    readonly property color color13: Prefs.color13Override !== "" ? Prefs.color13Override : "#EBCB8B"
    readonly property color color14: Prefs.color14Override !== "" ? Prefs.color14Override : "#A3BE8C"
    readonly property color color15: Prefs.color15Override !== "" ? Prefs.color15Override : "#B48EAD"

    // ── Fonts ────────────────────────────────────────────────────────────────
    readonly property string fontMono: Prefs.fontMono   // user-adjustable
    readonly property string fontNerd: Prefs.fontNerd   // user-adjustable
    readonly property string fontCJK:  "Sarasa Mono SC" // constant — not user-adjustable in v1

    // =========================================================================
    // ─── Mat3 Roles (populated by matugen; fall back to colorN when unset) ───
    // =========================================================================
    readonly property color mat3Primary:              Prefs.mat3PrimaryOverride              !== "" ? Prefs.mat3PrimaryOverride              : style.color10
    readonly property color mat3PrimaryContainer:     Prefs.mat3PrimaryContainerOverride     !== "" ? Prefs.mat3PrimaryContainerOverride     : Qt.darker(style.color10, 2.4)
    readonly property color mat3Background:           Prefs.mat3BackgroundOverride           !== "" ? Prefs.mat3BackgroundOverride           : style.color0
    readonly property color mat3OnBackground:         Prefs.mat3OnBackgroundOverride         !== "" ? Prefs.mat3OnBackgroundOverride         : style.color6
    readonly property color mat3SurfaceContainerLow:  Prefs.mat3SurfaceContainerLowOverride  !== "" ? Prefs.mat3SurfaceContainerLowOverride  : style.color1
    readonly property color mat3SurfaceContainerHigh: Prefs.mat3SurfaceContainerHighOverride !== "" ? Prefs.mat3SurfaceContainerHighOverride : style.color2
    readonly property color mat3OnSurface:            Prefs.mat3OnSurfaceOverride            !== "" ? Prefs.mat3OnSurfaceOverride            : style.color5
    readonly property color mat3OnSurfaceVariant:     Prefs.mat3OnSurfaceVariantOverride     !== "" ? Prefs.mat3OnSurfaceVariantOverride     : style.color4
    readonly property color mat3Outline:              Prefs.mat3OutlineOverride              !== "" ? Prefs.mat3OutlineOverride              : style.color3
    readonly property color mat3OutlineVariant:       Prefs.mat3OutlineVariantOverride       !== "" ? Prefs.mat3OutlineVariantOverride       : style.color1
    readonly property color mat3Error:                Prefs.mat3ErrorOverride                !== "" ? Prefs.mat3ErrorOverride                : style.color11
    readonly property color mat3ErrorContainer:       Prefs.mat3ErrorContainerOverride       !== "" ? Prefs.mat3ErrorContainerOverride       : Qt.darker(style.color11, 2.4)

    // =========================================================================
    // ─── Fixed (Semantic Tokens) ─────────────────────────────────────────────
    // =========================================================================

    // ── Surfaces & Structure ─────────────────────────────────────────────────
    readonly property color pillBgColor:       style.mat3Background
    readonly property color panelBgColor:      style.mat3Background
    readonly property color panelBorderColor:  style.mat3OutlineVariant
    readonly property color panelDividerColor: style.mat3OutlineVariant
    readonly property color surfaceLowColor:   style.mat3SurfaceContainerLow
    readonly property color surfaceMidColor:   style.mat3SurfaceContainerHigh

    // ── Borders ──────────────────────────────────────────────────────────────
    // borderFaintColor drives pill border, panel border, and panel divider.
    // "vibrant" steps up to mat3Outline for a more visible container edge.
    readonly property color borderFaintColor:  Prefs.borderColorMode === "vibrant" ? style.mat3Outline : style.mat3OutlineVariant
    readonly property color borderSoftColor:   style.mat3Outline

    // ── Accent ───────────────────────────────────────────────────────────────
    readonly property color accentBgColor:   style.mat3PrimaryContainer
    readonly property color accentBgHover:   Qt.lighter(style.mat3PrimaryContainer, 1.3)
    readonly property color accentColor:     style.mat3Primary
    readonly property color criticalBgColor: style.mat3ErrorContainer
    readonly property color successBgColor:  Qt.darker(style.color14, 2.4)

    // ── Text ─────────────────────────────────────────────────────────────────
    readonly property color textPrimary:   style.mat3OnBackground   // headings, pill text
    readonly property color textNormal:    style.mat3OnSurface       // standard body
    readonly property color textSecondary: style.mat3OnSurfaceVariant // secondary content, labels
    readonly property color textMuted:     style.mat3Outline          // de-emphasised / timestamps
    readonly property color textFaint:     style.mat3OutlineVariant   // barely-visible anchors
    readonly property color textAccent:    style.mat3Primary          // accent links, highlighted text
    readonly property color textCritical:  style.mat3Error            // error / alert
    readonly property color textSuccess:   style.color14              // completion / positive

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
    readonly property int pillBorderWidth:    Prefs.pillBorderWidth     // pill container
    readonly property int borderWidth:        Prefs.borderWidth         // panel containers
    readonly property int elementBorderWidth: Prefs.elementBorderWidth  // buttons, inputs
}
