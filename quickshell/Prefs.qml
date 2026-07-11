pragma Singleton
import QtQuick
import QtCore

Item {
    id: root

    // ── Persistence ──────────────────────────────────────────────────────────
    // Shares pillbox.conf with SettingsProcess — different keys, no conflict.
    Settings {
        id: _store
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/pillbox.conf"

        property string fontMono:           "JetBrainsMono Nerd Font"
        property string fontNerd:           "JetBrainsMono Nerd Font"
        property int    fontSizePill:       13
        property int    fontSizeBase:       10
        property real   radiusScale:        1.0
        property int    pillBorderWidth:    1
        property int    borderWidth:        1
        property int    elementBorderWidth: 1
        property string borderColorMode:   "subtle"   // "subtle" | "vibrant"

        property string wallpaperSourceType:  "color"
        property string wallpaperPath:        ""
        property string wallpaperColor:       "#2E3440"
        property string wallpaperDir:         ""
        property int    slideshowInterval:    60

        // ── Color extraction ──────────────────────────────────────────────────
        // When extractColors is true, WallpaperProcess runs matugen on every
        // image/video pick and writes the 16 extracted slots here.
        // Empty string = use Nord default in Style.qml.
        property bool   extractColors:    false
        property string color0Override:   ""
        property string color1Override:   ""
        property string color2Override:   ""
        property string color3Override:   ""
        property string color4Override:   ""
        property string color5Override:   ""
        property string color6Override:   ""
        property string color7Override:   ""
        property string color8Override:   ""
        property string color9Override:   ""
        property string color10Override:  ""
        property string color11Override:  ""
        property string color12Override:  ""
        property string color13Override:  ""
        property string color14Override:  ""
        property string color15Override:  ""

        // ── Mat3 semantic roles ───────────────────────────────────────────────
        // Written alongside base16 on each extraction. Empty = use colorN fallback in Style.qml.
        property string mat3PrimaryOverride:              ""
        property string mat3PrimaryContainerOverride:     ""
        property string mat3BackgroundOverride:           ""
        property string mat3OnBackgroundOverride:         ""
        property string mat3SurfaceContainerLowOverride:  ""
        property string mat3SurfaceContainerHighOverride: ""
        property string mat3OnSurfaceOverride:            ""
        property string mat3OnSurfaceVariantOverride:     ""
        property string mat3OutlineOverride:              ""
        property string mat3OutlineVariantOverride:       ""
        property string mat3ErrorOverride:                ""
        property string mat3ErrorContainerOverride:       ""
    }

    // ── Public (read) ─────────────────────────────────────────────────────────
    readonly property string fontMono:           _store.fontMono
    readonly property string fontNerd:           _store.fontNerd
    readonly property int    fontSizePill:       _store.fontSizePill
    readonly property int    fontSizeBase:       _store.fontSizeBase
    readonly property real   radiusScale:        _store.radiusScale
    readonly property int    pillBorderWidth:    _store.pillBorderWidth
    readonly property int    borderWidth:        _store.borderWidth
    readonly property int    elementBorderWidth: _store.elementBorderWidth
    readonly property string borderColorMode:    _store.borderColorMode

    readonly property string wallpaperSourceType:  _store.wallpaperSourceType
    readonly property string wallpaperPath:        _store.wallpaperPath
    readonly property string wallpaperColor:       _store.wallpaperColor
    readonly property string wallpaperDir:         _store.wallpaperDir
    readonly property int    slideshowInterval:    _store.slideshowInterval

    readonly property bool   extractColors:   _store.extractColors
    readonly property string color0Override:  _store.color0Override
    readonly property string color1Override:  _store.color1Override
    readonly property string color2Override:  _store.color2Override
    readonly property string color3Override:  _store.color3Override
    readonly property string color4Override:  _store.color4Override
    readonly property string color5Override:  _store.color5Override
    readonly property string color6Override:  _store.color6Override
    readonly property string color7Override:  _store.color7Override
    readonly property string color8Override:  _store.color8Override
    readonly property string color9Override:  _store.color9Override
    readonly property string color10Override: _store.color10Override
    readonly property string color11Override: _store.color11Override
    readonly property string color12Override: _store.color12Override
    readonly property string color13Override: _store.color13Override
    readonly property string color14Override: _store.color14Override
    readonly property string color15Override: _store.color15Override

    readonly property string mat3PrimaryOverride:              _store.mat3PrimaryOverride
    readonly property string mat3PrimaryContainerOverride:     _store.mat3PrimaryContainerOverride
    readonly property string mat3BackgroundOverride:           _store.mat3BackgroundOverride
    readonly property string mat3OnBackgroundOverride:         _store.mat3OnBackgroundOverride
    readonly property string mat3SurfaceContainerLowOverride:  _store.mat3SurfaceContainerLowOverride
    readonly property string mat3SurfaceContainerHighOverride: _store.mat3SurfaceContainerHighOverride
    readonly property string mat3OnSurfaceOverride:            _store.mat3OnSurfaceOverride
    readonly property string mat3OnSurfaceVariantOverride:     _store.mat3OnSurfaceVariantOverride
    readonly property string mat3OutlineOverride:              _store.mat3OutlineOverride
    readonly property string mat3OutlineVariantOverride:       _store.mat3OutlineVariantOverride
    readonly property string mat3ErrorOverride:                _store.mat3ErrorOverride
    readonly property string mat3ErrorContainerOverride:       _store.mat3ErrorContainerOverride

    // ── Setters (called by Appearance tab + WallpaperProcess) ────────────────
    function setFontMono(v)           { _store.fontMono           = v }
    function setFontNerd(v)           { _store.fontNerd           = v }
    function setFontSizePill(v)       { _store.fontSizePill       = v }
    function setFontSizeBase(v)       { _store.fontSizeBase       = v }
    function setRadiusScale(v)        { _store.radiusScale        = v }
    function setPillBorderWidth(v)    { _store.pillBorderWidth    = v }
    function setBorderWidth(v)        { _store.borderWidth        = v }
    function setElementBorderWidth(v) { _store.elementBorderWidth = v }
    function setBorderColorMode(v)    { _store.borderColorMode    = v }

    function setWallpaperSourceType(v)  { _store.wallpaperSourceType  = v }
    function setWallpaperPath(v)        { _store.wallpaperPath        = v }
    function setWallpaperColor(v)       { _store.wallpaperColor       = v }
    function setWallpaperDir(v)         { _store.wallpaperDir         = v }
    function setSlideshowInterval(v)    { _store.slideshowInterval    = v }

    function setExtractColors(v)    { _store.extractColors   = v }
    function setColor0Override(v)   { _store.color0Override  = v }
    function setColor1Override(v)   { _store.color1Override  = v }
    function setColor2Override(v)   { _store.color2Override  = v }
    function setColor3Override(v)   { _store.color3Override  = v }
    function setColor4Override(v)   { _store.color4Override  = v }
    function setColor5Override(v)   { _store.color5Override  = v }
    function setColor6Override(v)   { _store.color6Override  = v }
    function setColor7Override(v)   { _store.color7Override  = v }
    function setColor8Override(v)   { _store.color8Override  = v }
    function setColor9Override(v)   { _store.color9Override  = v }
    function setColor10Override(v)  { _store.color10Override = v }
    function setColor11Override(v)  { _store.color11Override = v }
    function setColor12Override(v)  { _store.color12Override = v }
    function setColor13Override(v)  { _store.color13Override = v }
    function setColor14Override(v)  { _store.color14Override = v }
    function setColor15Override(v)  { _store.color15Override = v }

    function setMat3PrimaryOverride(v)              { _store.mat3PrimaryOverride              = v }
    function setMat3PrimaryContainerOverride(v)     { _store.mat3PrimaryContainerOverride     = v }
    function setMat3BackgroundOverride(v)           { _store.mat3BackgroundOverride           = v }
    function setMat3OnBackgroundOverride(v)         { _store.mat3OnBackgroundOverride         = v }
    function setMat3SurfaceContainerLowOverride(v)  { _store.mat3SurfaceContainerLowOverride  = v }
    function setMat3SurfaceContainerHighOverride(v) { _store.mat3SurfaceContainerHighOverride = v }
    function setMat3OnSurfaceOverride(v)            { _store.mat3OnSurfaceOverride            = v }
    function setMat3OnSurfaceVariantOverride(v)     { _store.mat3OnSurfaceVariantOverride     = v }
    function setMat3OutlineOverride(v)              { _store.mat3OutlineOverride              = v }
    function setMat3OutlineVariantOverride(v)       { _store.mat3OutlineVariantOverride       = v }
    function setMat3ErrorOverride(v)                { _store.mat3ErrorOverride                = v }
    function setMat3ErrorContainerOverride(v)       { _store.mat3ErrorContainerOverride       = v }

    function clearColorOverrides() {
        _store.color0Override  = ""
        _store.color1Override  = ""
        _store.color2Override  = ""
        _store.color3Override  = ""
        _store.color4Override  = ""
        _store.color5Override  = ""
        _store.color6Override  = ""
        _store.color7Override  = ""
        _store.color8Override  = ""
        _store.color9Override  = ""
        _store.color10Override = ""
        _store.color11Override = ""
        _store.color12Override = ""
        _store.color13Override = ""
        _store.color14Override = ""
        _store.color15Override = ""
    }

    function clearMat3Overrides() {
        _store.mat3PrimaryOverride              = ""
        _store.mat3PrimaryContainerOverride     = ""
        _store.mat3BackgroundOverride           = ""
        _store.mat3OnBackgroundOverride         = ""
        _store.mat3SurfaceContainerLowOverride  = ""
        _store.mat3SurfaceContainerHighOverride = ""
        _store.mat3OnSurfaceOverride            = ""
        _store.mat3OnSurfaceVariantOverride     = ""
        _store.mat3OutlineOverride              = ""
        _store.mat3OutlineVariantOverride       = ""
        _store.mat3ErrorOverride                = ""
        _store.mat3ErrorContainerOverride       = ""
    }

    Component.onCompleted: console.log(
        "[Prefs] loaded | fontSizePill:", _store.fontSizePill,
        "| fontSizeBase:", _store.fontSizeBase,
        "| radiusScale:", _store.radiusScale,
        "| borderWidth:", _store.borderWidth,
        "| wallpaperSourceType:", _store.wallpaperSourceType,
        "| extractColors:", _store.extractColors)
}
