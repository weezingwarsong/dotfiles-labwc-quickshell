import QtQuick

QtObject {
    id: root

    // ── State ─────────────────────────────────────────────────────────────────

    property string _active: ""  // "" = none, "calendar" = calendar, etc.

    // ── API ───────────────────────────────────────────────────────────────────
    // Call toggle(panelId) to open a panel or dismiss it if already open.
    // Summoning a different panel while one is open replaces it immediately.

    function toggle(panelId) {
        if (_active === panelId) {
            _active = ""
            console.log("[PanelController] dismissed:", panelId)
        } else {
            if (_active !== "") console.log("[PanelController] replacing:", _active, "→", panelId)
            _active = panelId
            console.log("[PanelController] opened:", panelId)
        }
    }

    // ── Outputs ───────────────────────────────────────────────────────────────

    readonly property string activePanel: _active
    readonly property bool shouldShow: _active !== ""
}
