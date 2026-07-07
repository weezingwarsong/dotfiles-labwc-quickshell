pragma Singleton
import QtQuick
import QtCore

Item {
    id: root

    // ── Persistence ──────────────────────────────────────────────────────────
    // Shares pillbox.conf with SettingsProcess — different keys, no conflict.
    Settings {
        id: _store
        location: "file://" + StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/pillbox/pillbox.conf"

        property string fontMono:           "JetBrainsMono Nerd Font"
        property string fontNerd:           "JetBrainsMono Nerd Font"
        property int    fontSizePill:       13
        property int    fontSizeBase:       10
        property real   radiusScale:        1.0
        property int    borderWidth:        1
        property int    elementBorderWidth: 1
    }

    // ── Public (read) ─────────────────────────────────────────────────────────
    readonly property string fontMono:           _store.fontMono
    readonly property string fontNerd:           _store.fontNerd
    readonly property int    fontSizePill:       _store.fontSizePill
    readonly property int    fontSizeBase:       _store.fontSizeBase
    readonly property real   radiusScale:        _store.radiusScale
    readonly property int    borderWidth:        _store.borderWidth
    readonly property int    elementBorderWidth: _store.elementBorderWidth

    // ── Setters (called by Appearance tab) ───────────────────────────────────
    function setFontMono(v)           { _store.fontMono           = v }
    function setFontNerd(v)           { _store.fontNerd           = v }
    function setFontSizePill(v)       { _store.fontSizePill       = v }
    function setFontSizeBase(v)       { _store.fontSizeBase       = v }
    function setRadiusScale(v)        { _store.radiusScale        = v }
    function setBorderWidth(v)        { _store.borderWidth        = v }
    function setElementBorderWidth(v) { _store.elementBorderWidth = v }

    Component.onCompleted: console.log(
        "[Prefs] loaded | fontSizePill:", _store.fontSizePill,
        "| fontSizeBase:", _store.fontSizeBase,
        "| radiusScale:", _store.radiusScale,
        "| borderWidth:", _store.borderWidth)
}
