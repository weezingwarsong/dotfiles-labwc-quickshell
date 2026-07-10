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
        property int    borderWidth:        1
        property int    elementBorderWidth: 1

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
    }

    // ── Public (read) ─────────────────────────────────────────────────────────
    readonly property string fontMono:           _store.fontMono
    readonly property string fontNerd:           _store.fontNerd
    readonly property int    fontSizePill:       _store.fontSizePill
    readonly property int    fontSizeBase:       _store.fontSizeBase
    readonly property real   radiusScale:        _store.radiusScale
    readonly property int    borderWidth:        _store.borderWidth
    readonly property int    elementBorderWidth: _store.elementBorderWidth

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

    // ── Setters (called by Appearance tab + WallpaperProcess) ────────────────
    function setFontMono(v)           { _store.fontMono           = v }
    function setFontNerd(v)           { _store.fontNerd           = v }
    function setFontSizePill(v)       { _store.fontSizePill       = v }
    function setFontSizeBase(v)       { _store.fontSizeBase       = v }
    function setRadiusScale(v)        { _store.radiusScale        = v }
    function setBorderWidth(v)        { _store.borderWidth        = v }
    function setElementBorderWidth(v) { _store.elementBorderWidth = v }

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

    Component.onCompleted: console.log(
        "[Prefs] loaded | fontSizePill:", _store.fontSizePill,
        "| fontSizeBase:", _store.fontSizeBase,
        "| radiusScale:", _store.radiusScale,
        "| borderWidth:", _store.borderWidth,
        "| wallpaperSourceType:", _store.wallpaperSourceType,
        "| extractColors:", _store.extractColors)
}
