pragma Singleton
import QtQuick

QtObject {
    id: style

    // =========================================================================
    // ─── Mat3 Roles ───────────────────────────────────────────────────────────
    // =========================================================================
    // Populated live from Colors.md3 (matugen-generated colors.json).
    // Fall back to Nord equivalents when no wallpaper has been extracted yet.

    readonly property color transparent: "transparent"

    readonly property color mat3Primary:              Colors.md3["primary"]                 || "#5E81AC"
    readonly property color mat3OnPrimary:            Colors.md3["on_primary"]              || "#2E3440"
    readonly property color mat3PrimaryContainer:     Colors.md3["primary_container"]       || "#1d2d40"
    readonly property color mat3OnPrimaryContainer:   Colors.md3["on_primary_container"]    || "#C8DCF0"

    readonly property color mat3Secondary:            Colors.md3["secondary"]               || "#81A1C1"
    readonly property color mat3OnSecondary:          Colors.md3["on_secondary"]            || "#2E3440"
    readonly property color mat3SecondaryContainer:   Colors.md3["secondary_container"]     || "#2a3a4d"
    readonly property color mat3OnSecondaryContainer: Colors.md3["on_secondary_container"]  || "#C8DCF0"

    readonly property color mat3Tertiary:             Colors.md3["tertiary"]                || "#A3BE8C"
    readonly property color mat3OnTertiary:           Colors.md3["on_tertiary"]             || "#2E3440"
    readonly property color mat3TertiaryContainer:    Colors.md3["tertiary_container"]      || "#2a3d20"
    readonly property color mat3OnTertiaryContainer:  Colors.md3["on_tertiary_container"]   || "#C8E6B0"

    readonly property color mat3Error:                Colors.md3["error"]                   || "#BF616A"
    readonly property color mat3OnError:              Colors.md3["on_error"]                || "#2E3440"
    readonly property color mat3ErrorContainer:       Colors.md3["error_container"]         || "#4d1f22"
    readonly property color mat3OnErrorContainer:     Colors.md3["on_error_container"]      || "#F0C0C3"

    readonly property color mat3Background:           Colors.md3["background"]              || "#2E3440"
    readonly property color mat3OnBackground:         Colors.md3["on_background"]           || "#ECEFF4"
    readonly property color mat3Surface:              Colors.md3["surface"]                 || "#2E3440"
    readonly property color mat3OnSurface:            Colors.md3["on_surface"]              || "#E5E9F0"
    readonly property color mat3SurfaceVariant:       Colors.md3["surface_variant"]         || "#3B4252"
    readonly property color mat3OnSurfaceVariant:     Colors.md3["on_surface_variant"]      || "#D8DEE9"
    readonly property color mat3SurfaceContainerLow:  Colors.md3["surface_container_low"]   || "#3B4252"
    readonly property color mat3SurfaceContainer:     Colors.md3["surface_container"]       || "#404858"
    readonly property color mat3SurfaceContainerHigh: Colors.md3["surface_container_high"]  || "#434C5E"
    readonly property color mat3Outline:              Colors.md3["outline"]                 || "#4C566A"
    readonly property color mat3OutlineVariant:       Colors.md3["outline_variant"]         || "#3B4252"

    // ── Fonts ────────────────────────────────────────────────────────────────
    readonly property string fontMono: Prefs.fontMono
    readonly property string fontNerd: Prefs.fontNerd
    readonly property string fontCJK:  "Sarasa Mono SC"

    // =========================================================================
    // ─── Semantic Tokens ──────────────────────────────────────────────────────
    // =========================================================================

    // ── Surfaces & Structure ─────────────────────────────────────────────────
    readonly property color pillBgColor:       style.mat3Background
    readonly property color panelBgColor:      style.mat3Background
    readonly property color panelBorderColor:  style.mat3OutlineVariant
    readonly property color panelDividerColor: style.mat3OutlineVariant
    readonly property color surfaceLowColor:   style.mat3SurfaceContainerLow
    readonly property color surfaceMidColor:   style.mat3SurfaceContainerHigh

    // ── Borders ──────────────────────────────────────────────────────────────
    readonly property color borderFaintColor: Prefs.borderColorMode === "vibrant" ? style.mat3Outline : style.mat3OutlineVariant
    readonly property color borderSoftColor:  style.mat3Outline

    // ── Accent ───────────────────────────────────────────────────────────────
    readonly property color accentColor:    style.mat3Primary
    readonly property color accentBgColor:  style.mat3PrimaryContainer
    readonly property color accentBgHover:  Qt.lighter(style.mat3PrimaryContainer, 1.3)

    // ── States ───────────────────────────────────────────────────────────────
    readonly property color criticalBgColor: style.mat3ErrorContainer
    readonly property color successBgColor:  style.mat3TertiaryContainer

    // ── Text ─────────────────────────────────────────────────────────────────
    readonly property color textPrimary:   style.mat3OnBackground
    readonly property color textNormal:    style.mat3OnSurface
    readonly property color textSecondary: style.mat3OnSurfaceVariant
    readonly property color textMuted:     style.mat3Outline
    readonly property color textFaint:     style.mat3OutlineVariant
    readonly property color textAccent:    style.mat3Primary
    readonly property color textCritical:  style.mat3Error
    readonly property color textSuccess:   style.mat3Tertiary

    // ── Layout constants ─────────────────────────────────────────────────────
    readonly property int buttonHeight: 22
    readonly property int panelMargin:  12

    // =========================================================================
    // ─── Prefs-derived (user-adjustable) ─────────────────────────────────────
    // =========================================================================

    // ── Typography ───────────────────────────────────────────────────────────
    readonly property int fontSizePill:    Prefs.fontSizePill
    readonly property int fontSizeHeading: Prefs.fontSizeBase + 2
    readonly property int fontSizeBody:    Prefs.fontSizeBase
    readonly property int fontSizeSubtle:  Prefs.fontSizeBase - 1

    // ── Radius (scale-driven) ────────────────────────────────────────────────
    readonly property real radSm: Math.round(4  * Prefs.radiusScale)
    readonly property real radMd: Math.round(6  * Prefs.radiusScale)
    readonly property real radLg: Math.round(10 * Prefs.radiusScale)

    // ── Border widths ────────────────────────────────────────────────────────
    readonly property int pillBorderWidth:    Prefs.pillBorderWidth
    readonly property int borderWidth:        Prefs.borderWidth
    readonly property int elementBorderWidth: Prefs.elementBorderWidth
}
