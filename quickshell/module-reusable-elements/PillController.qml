import QtQuick

QtObject {
    id: root

    // ── Inputs ────────────────────────────────────────────────────────────────

    property bool hovered: false
    property var timePill: null
    property var workspacePill: null
    property var windowPill: null
    property var mprisPill: null

    // ── Stage 1: Winner ───────────────────────────────────────────────────────
    // Each pill exposes priority: int. Highest wins. No pill-specific logic here —
    // adding a new pill never requires touching PillController.
    //
    // Priority table — leave gaps so future pills can insert without renumbering:
    //   200  WindowPill      switcher open (transient, time-critical)
    //   100  WorkspacePill   workspace flash (transient, time-critical)
    //    10  TimePill        calendar imminent / timer active
    //     5  MprisPill       track actively playing
    //     1  TimePill idle   permanent fallback (always shows time)
    //     0  any pill off    inactive, won't win

    readonly property var winner: {
        var pills = []
        if (windowPill)    pills.push(windowPill)
        if (workspacePill) pills.push(workspacePill)
        if (mprisPill)     pills.push(mprisPill)
        if (timePill)      pills.push(timePill)
        return pills.reduce(function(best, p) {
            return (!best || p.priority > best.priority) ? p : best
        }, null)
    }

    // ── Stage 2: Show/hide ────────────────────────────────────────────────────
    // Whether to show the pill at all. Three independent triggers; any one
    // is sufficient. Winner is already known — this is just the gate.

    property bool _peekActive: false
    property bool _userDismissed: false

    // Mirrors winner.shouldReveal — when a content condition ends naturally,
    // clear the dismiss gate so future conditions are not silenced.
    property bool contentActive: winner ? winner.shouldReveal : false
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
        if (!_userDismissed && winner && winner.shouldReveal) return true     // content-driven
        return false
    }

    // ── Outputs ───────────────────────────────────────────────────────────────

    readonly property var activePill: shouldShow ? winner : null
}
