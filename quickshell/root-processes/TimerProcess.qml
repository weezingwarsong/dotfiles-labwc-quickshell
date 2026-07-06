import QtQuick

Item {
    id: root

    property string mode:     "idle"   // "idle" | "timer" | "stopwatch"
    property bool   active:   false
    property int    duration: 90       // seconds; default 1m 30s

    property real   _remainMs:  0
    property real   _elapsedMs: 0
    property real   _anchorMs:  0

    property string displayText:  "00:01:30"
    property string displayCenti: ""          // ".cs" when centiseconds are shown, else ""

    // ── Mode switching (used by TimerWidget; does not start) ──────────────────

    function setMode(m) {
        root.active = false
        tickTimer.stop()
        if (m === "stopwatch") {
            root.mode       = "stopwatch"
            root._elapsedMs = 0
        } else {
            root.mode      = "timer"
            root._remainMs = root.duration * 1000
        }
        _updateDisplay()
    }

    // ── Timer (countdown) ─────────────────────────────────────────────────────

    function setTimer(seconds) {
        var s = Math.max(1, seconds)
        root.mode      = "timer"
        root.duration  = s
        root._remainMs = s * 1000
        root.active    = false
        tickTimer.stop()
        _updateDisplay()
        console.log("[TimerProcess] timer set:", s, "s")
    }

    function startTimer() {
        if (root.mode !== "timer" || root._remainMs <= 0) return
        root._anchorMs = Date.now() - (root.duration * 1000 - root._remainMs)
        root.active = true
        tickTimer.start()
        console.log("[TimerProcess] timer started")
    }

    function pauseTimer() {
        if (!root.active) return
        root._remainMs = Math.max(0, root.duration * 1000 - (Date.now() - root._anchorMs))
        root.active = false
        tickTimer.stop()
        _updateDisplay()
        console.log("[TimerProcess] timer paused:", root.displayText)
    }

    function resetTimer() {
        root.active    = false
        root._remainMs = root.duration * 1000
        tickTimer.stop()
        _updateDisplay()
        console.log("[TimerProcess] timer reset")
    }

    // ── Stopwatch (countup) ───────────────────────────────────────────────────

    function startStopwatch() {
        root.mode      = "stopwatch"
        root._anchorMs = Date.now() - root._elapsedMs
        root.active    = true
        tickTimer.start()
        console.log("[TimerProcess] stopwatch started")
    }

    function stopStopwatch() {
        if (!root.active) return
        root._elapsedMs = Date.now() - root._anchorMs
        root.active     = false
        tickTimer.stop()
        _updateDisplay()
        console.log("[TimerProcess] stopwatch stopped:", root.displayText)
    }

    function resetStopwatch() {
        root.active     = false
        root._elapsedMs = 0
        tickTimer.stop()
        _updateDisplay()
        console.log("[TimerProcess] stopwatch reset")
    }

    // ── Display formatting ────────────────────────────────────────────────────

    function _fmt2(n) { return n < 10 ? "0" + n : "" + n }

    function _updateDisplay() {
        if (root.mode === "stopwatch") {
            var ms = root._elapsedMs
            var cs = Math.floor((ms % 1000) / 10)
            var s  = Math.floor(ms / 1000) % 60
            var m  = Math.floor(ms / 60000) % 60
            var h  = Math.floor(ms / 3600000)
            root.displayText  = _fmt2(h) + ":" + _fmt2(m) + ":" + _fmt2(s)
            root.displayCenti = "." + _fmt2(cs)
        } else {
            var ms2 = root._remainMs
            var s2  = Math.floor(ms2 / 1000) % 60
            var m2  = Math.floor(ms2 / 60000) % 60
            var h2  = Math.floor(ms2 / 3600000)
            root.displayText = _fmt2(h2) + ":" + _fmt2(m2) + ":" + _fmt2(s2)
            // show centiseconds only in the last 10 seconds of an active countdown
            if (root.mode === "timer" && root.active && ms2 < 10000) {
                root.displayCenti = "." + _fmt2(Math.floor((ms2 % 1000) / 10))
            } else {
                root.displayCenti = ""
            }
        }
    }

    // ── Tick ─────────────────────────────────────────────────────────────────

    Timer {
        id: tickTimer
        interval: 50
        repeat: true
        onTriggered: {
            if (root.mode === "timer") {
                root._remainMs = Math.max(0, root.duration * 1000 - (Date.now() - root._anchorMs))
                _updateDisplay()
                if (root._remainMs === 0) {
                    root.active = false
                    tickTimer.stop()
                    console.log("[TimerProcess] countdown finished")
                }
            } else if (root.mode === "stopwatch") {
                root._elapsedMs = Date.now() - root._anchorMs
                _updateDisplay()
            }
        }
    }

    Component.onCompleted: {
        root._remainMs = root.duration * 1000
        _updateDisplay()
        console.log("[TimerProcess] started, default duration:", root.duration, "s")
    }
}
