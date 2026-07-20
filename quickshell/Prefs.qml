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
        property string fontVisClock:       "JetBrainsMono Nerd Font"
        property int    fontSizeVisClock:   100
        property int    fontSizePill:       13
        property int    fontSizeBase:       10
        property int    pillRadius:          10
        property int    panelRadius:         10
        property int    panelElementRadius:  4
        property int    pillBorderWidth:    1
        property int    pillPaddingV:        20
        property int    panelCardPadding:   12
        property int    panelElementPadding: 20
        property int    borderWidth:        1
        property int    elementBorderWidth: 1
        property string borderColorMode:   "subtle"   // "subtle" | "vibrant"

        property int panelOffsetY: 10   // % of screen width; drives vertical position + height cap
        property int panelWidth:   15   // % of screen width

        property string wallpaperSourceType:  "color"
        property string wallpaperPath:        ""
        property string wallpaperColor:       "#2E3440"
        property string wallpaperDir:         ""
        property int    slideshowInterval:    60

        // When extractColors is true, WallpaperProcess runs matugen on every
        // image/video pick, writing colors.json which Colors.qml watches live.
        property bool extractColors: false

        // Media dirs — empty string means "use the pillbox/media/ symlink default".
        // User-configurable via Settings panel (future). Resolved at runtime by
        // ScreenshotProcess / ScreenrecProcess.
        property string screenshotDir: ""
        property string recordingDir:  ""
        property string replayDir:     ""

        // Screen recorder mode — persists across restarts.
        property string recMode: "oneshot"   // "oneshot" | "replay"

        property int notificationTimeout: 5000   // ms; shown in Settings as seconds

        // Bank
        property int bankMaxLines:   8    // max visible lines for summary/body text in bank
        property int bankThumbWidth: 72   // screenshot thumbnail width (px) in bank
    }

    // ── Public (read) ─────────────────────────────────────────────────────────
    readonly property string fontMono:           _store.fontMono
    readonly property string fontNerd:           _store.fontNerd
    readonly property string fontVisClock:       _store.fontVisClock
    readonly property int    fontSizeVisClock:   _store.fontSizeVisClock
    readonly property int    fontSizePill:       _store.fontSizePill
    readonly property int    fontSizeBase:       _store.fontSizeBase
    readonly property int    pillRadius:         _store.pillRadius
    readonly property int    panelRadius:        _store.panelRadius
    readonly property int    panelElementRadius: _store.panelElementRadius
    readonly property int    pillBorderWidth:    _store.pillBorderWidth
    readonly property int    pillPaddingV:        _store.pillPaddingV
    readonly property int    panelCardPadding:   _store.panelCardPadding
    readonly property int    panelElementPadding: _store.panelElementPadding
    readonly property int    borderWidth:        _store.borderWidth
    readonly property int    elementBorderWidth: _store.elementBorderWidth
    readonly property string borderColorMode:    _store.borderColorMode

    readonly property int panelOffsetY: _store.panelOffsetY
    readonly property int panelWidth:   _store.panelWidth

    readonly property string wallpaperSourceType:  _store.wallpaperSourceType
    readonly property string wallpaperPath:        _store.wallpaperPath
    readonly property string wallpaperColor:       _store.wallpaperColor
    readonly property string wallpaperDir:         _store.wallpaperDir
    readonly property int    slideshowInterval:    _store.slideshowInterval

    readonly property bool extractColors: _store.extractColors

    readonly property string screenshotDir: _store.screenshotDir
    readonly property string recordingDir:  _store.recordingDir
    readonly property string replayDir:     _store.replayDir
    readonly property string recMode:       _store.recMode
    readonly property int    notificationTimeout: _store.notificationTimeout
    readonly property int    bankMaxLines:        _store.bankMaxLines
    readonly property int    bankThumbWidth:      _store.bankThumbWidth

    // ── Setters (called by Appearance tab + WallpaperProcess) ────────────────
    function setFontMono(v)           { _store.fontMono           = v }
    function setFontNerd(v)           { _store.fontNerd           = v }
    function setFontVisClock(v)       { _store.fontVisClock       = v }
    function setFontSizeVisClock(v)   { _store.fontSizeVisClock   = v }
    function setFontSizePill(v)       { _store.fontSizePill       = v }
    function setFontSizeBase(v)       { _store.fontSizeBase       = v }
    function setPillRadius(v)         { _store.pillRadius         = v }
    function setPanelRadius(v)        { _store.panelRadius        = v }
    function setPanelElementRadius(v) { _store.panelElementRadius = v }
    function setPillBorderWidth(v)    { _store.pillBorderWidth    = v }
    function setPillPaddingV(v)        { _store.pillPaddingV        = v }
    function setPanelCardPadding(v)   { _store.panelCardPadding   = v }
    function setPanelElementPadding(v) { _store.panelElementPadding = v }
    function setBorderWidth(v)        { _store.borderWidth        = v }
    function setElementBorderWidth(v) { _store.elementBorderWidth = v }
    function setBorderColorMode(v)    { _store.borderColorMode    = v }

    function setPanelOffsetY(v) { _store.panelOffsetY = v }
    function setPanelWidth(v)   { _store.panelWidth   = v }

    function setWallpaperSourceType(v)  { _store.wallpaperSourceType  = v }
    function setWallpaperPath(v)        { _store.wallpaperPath        = v }
    function setWallpaperColor(v)       { _store.wallpaperColor       = v }
    function setWallpaperDir(v)         { _store.wallpaperDir         = v }
    function setSlideshowInterval(v)    { _store.slideshowInterval    = v }

    function setExtractColors(v) { _store.extractColors = v }

    function setScreenshotDir(v)        { _store.screenshotDir        = v }
    function setRecordingDir(v)         { _store.recordingDir         = v }
    function setReplayDir(v)            { _store.replayDir            = v }
    function setRecMode(v)              { _store.recMode              = v }
    function setNotificationTimeout(v)  { _store.notificationTimeout  = v }
    function setBankMaxLines(v)         { _store.bankMaxLines         = v }
    function setBankThumbWidth(v)       { _store.bankThumbWidth       = v }

    Component.onCompleted: console.log(
        "[Prefs] loaded | fontSizePill:", _store.fontSizePill,
        "| fontSizeBase:", _store.fontSizeBase,
        "| pillPaddingV:", _store.pillPaddingV,
        "| pillRadius:", _store.pillRadius,
        "| panelRadius:", _store.panelRadius,
        "| panelElementRadius:", _store.panelElementRadius,
        "| borderWidth:", _store.borderWidth,
        "| wallpaperSourceType:", _store.wallpaperSourceType,
        "| extractColors:", _store.extractColors)
}
