import QtQuick

Item {
    id: root

    signal timerCompleted(string id)

    // { id: { durationMs: int, startedAt: real } }
    property var _timers: ({})

    // Register or restart a timer. Duplicate id resets startedAt and durationMs.
    function register(id, durationMs) {
        var restarted = _timers.hasOwnProperty(id)
        _timers[id] = { durationMs: durationMs, startedAt: Date.now() }
        if (!tickTimer.running) tickTimer.start()
        if (restarted)
            console.log("[LocalTimerProcess] restarted:", id, durationMs + "ms")
        else
            console.log("[LocalTimerProcess] registered:", id, durationMs + "ms")
    }

    // Remove a timer immediately. No timerCompleted signal is emitted.
    function kill(id) {
        if (!_timers.hasOwnProperty(id)) {
            console.warn("[LocalTimerProcess] kill: unknown id '" + id + "' (already completed or never registered)")
            return
        }
        delete _timers[id]
        console.log("[LocalTimerProcess] killed:", id)
        if (Object.keys(_timers).length === 0) {
            tickTimer.stop()
            console.log("[LocalTimerProcess] tick stopped (no active timers)")
        }
    }

    // Returns "started" if the timer is active, null if not found (completed or never registered).
    function status(id) {
        return _timers.hasOwnProperty(id) ? "started" : null
    }

    // Milliseconds elapsed since registration. Returns 0 if not found.
    function elapsed(id) {
        if (!_timers.hasOwnProperty(id)) return 0
        return Date.now() - _timers[id].startedAt
    }

    // Milliseconds remaining, clamped to 0. Returns 0 if not found.
    function remaining(id) {
        if (!_timers.hasOwnProperty(id)) return 0
        return Math.max(0, _timers[id].durationMs - (Date.now() - _timers[id].startedAt))
    }

    Timer {
        id: tickTimer
        interval: 50
        repeat: true
        onTriggered: {
            var now = Date.now()
            // Collect expired ids first to avoid mutating _timers during iteration.
            var expired = []
            for (var id in root._timers) {
                var t = root._timers[id]
                if (now - t.startedAt >= t.durationMs)
                    expired.push(id)
            }
            for (var i = 0; i < expired.length; i++) {
                var cid = expired[i]
                delete root._timers[cid]
                console.log("[LocalTimerProcess] completed:", cid)
                root.timerCompleted(cid)
            }
            if (Object.keys(root._timers).length === 0) {
                tickTimer.stop()
                console.log("[LocalTimerProcess] tick stopped (no active timers)")
            }
        }
    }

    Component.onCompleted: {
        console.log("[LocalTimerProcess] ready")
    }
}
