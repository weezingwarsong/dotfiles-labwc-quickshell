import QtQuick

Item {
    id: root

    property string mode: "idle"    // "idle" | "timer" | "stopwatch"
    property bool active: false
    property int duration: 0        // total seconds set (timer mode)
    property int remaining: 0       // seconds left (timer mode)
    property int elapsed: 0         // seconds passed (stopwatch mode)
    property string displayText: "--:--"

    function setTimer(seconds) {
        root.mode = "timer"
        root.duration = seconds
        root.remaining = seconds
        root.active = false
        tickTimer.stop()
        _updateDisplay()
        console.log("[TimerProcess] timer set:", seconds, "seconds")
    }

    function startTimer() {
        if (root.mode !== "timer" || root.remaining <= 0) return
        root.active = true
        tickTimer.start()
        console.log("[TimerProcess] timer started, remaining:", root.remaining)
    }

    function pauseTimer() {
        root.active = false
        tickTimer.stop()
        console.log("[TimerProcess] timer paused, remaining:", root.remaining)
    }

    function resetTimer() {
        root.active = false
        tickTimer.stop()
        root.remaining = root.duration
        _updateDisplay()
        console.log("[TimerProcess] timer reset to:", root.duration)
    }

    function startStopwatch() {
        root.mode = "stopwatch"
        root.elapsed = 0
        root.active = true
        tickTimer.start()
        console.log("[TimerProcess] stopwatch started")
    }

    function stopStopwatch() {
        root.active = false
        tickTimer.stop()
        console.log("[TimerProcess] stopwatch stopped, elapsed:", root.elapsed)
    }

    function resetStopwatch() {
        root.active = false
        tickTimer.stop()
        root.elapsed = 0
        _updateDisplay()
        console.log("[TimerProcess] stopwatch reset")
    }

    function _updateDisplay() {
        var secs = root.mode === "stopwatch" ? root.elapsed : root.remaining
        var m = Math.floor(secs / 60)
        var s = secs % 60
        root.displayText = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    Timer {
        id: tickTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.mode === "timer") {
                root.remaining = Math.max(0, root.remaining - 1)
                _updateDisplay()
                console.log("[TimerProcess] tick:", root.displayText)
                if (root.remaining === 0) {
                    root.active = false
                    tickTimer.stop()
                    console.log("[TimerProcess] timer finished!")
                }
            } else if (root.mode === "stopwatch") {
                root.elapsed++
                _updateDisplay()
                console.log("[TimerProcess] stopwatch:", root.displayText)
            }
        }
    }

    Component.onCompleted: console.log("[TimerProcess] started")
}
