import QtQuick

QtObject {
    id: root

    // ── State ─────────────────────────────────────────────────────────────────

    property string _active: ""

    // Ordered navigation row. Window switcher is excluded by design.
    // Append new panel IDs here as panels are built.
    readonly property var panelOrder: ["calendar", "control", "mediaPlayer", "notifications", "settings", "wallpaper"]

    // ── API ───────────────────────────────────────────────────────────────────

    function toggle(panelId) {
        if (_active === panelId) {
            _active = ""
        } else {
            _active = panelId
        }
    }

    // Cycle through panelOrder. direction: +1 = next, -1 = prev, wraps.
    // No-op if the active panel is not in the order (e.g. windowSwitcher).
    function navigate(direction) {
        var idx = panelOrder.indexOf(_active)
        if (idx === -1) return
        var n = panelOrder.length
        _active = panelOrder[((idx + direction) % n + n) % n]
    }

    // ── Outputs ───────────────────────────────────────────────────────────────

    readonly property string activePanel: _active
    readonly property bool shouldShow: _active !== ""
}
