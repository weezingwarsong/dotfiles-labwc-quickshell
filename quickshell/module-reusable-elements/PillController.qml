import QtQuick

QtObject {
    id: root

    // ── Inputs ────────────────────────────────────────────────────────────────

    property bool hovered: false
    property var timePill: null
    property var workspacePill: null
    // future pills registered here in priority order

    // ── Stage 1: Winner ───────────────────────────────────────────────────────
    // Which pill has the most relevant content right now, independent of
    // whether anything is showing. Pre-computed so display is instant on reveal.
    //
    // Priority order (highest → lowest):
    //   1. WorkspacePill — workspace flash is time-critical; always wins if active
    //   2. TimePill — calendar imminent, timer active, or default time display

    readonly property var winner: {
        if (workspacePill && workspacePill.shouldShow) return workspacePill
        if (timePill) return timePill
        return null
    }

    // ── Stage 2: Show/hide ────────────────────────────────────────────────────
    // Whether to show the pill at all. Three independent triggers; any one
    // is sufficient. Winner is already known — this is just the gate.

    property bool _peekActive: false
    property bool _userDismissed: false

    // Mirrors winner.shouldShow — when a content condition ends naturally,
    // clear the dismiss gate so future conditions are not silenced.
    property bool contentActive: winner ? winner.shouldShow : false
    onContentActiveChanged: {
        if (!contentActive) _userDismissed = false
    }

    function triggerPeek() {
        if (_peekActive) {
            _peekActive = false
            _peekTimer.stop()
            _userDismissed = true
            console.log("[PillController] peek dismissed")
        } else {
            _peekActive = true
            _userDismissed = false
            _peekTimer.restart()
            console.log("[PillController] peek triggered")
        }
    }

    property var _peekTimer: Timer {
        interval: 5000
        onTriggered: {
            root._peekActive = false
            root._userDismissed = false
            console.log("[PillController] peek expired")
        }
    }

    readonly property bool shouldShow: {
        if (hovered)     return true                                         // hover always works
        if (_peekActive) return true                                         // explicit peek
        if (!_userDismissed && winner && winner.shouldShow) return true      // content-driven
        return false
    }

    // ── Outputs ───────────────────────────────────────────────────────────────

    readonly property var activePill: shouldShow ? winner : null
}
