import QtQuick

Item {
    id: root

    signal timerCompleted(string id)
    signal timerPaused(string id)
    signal timerResumed(string id)

    // { id: { durationMs: int, startedAt: real, pausedRemaining?: real } }
    // pausedRemaining defined → timer is paused; absent → timer is running.
    property var _timers: ({})

    // Register or restart a timer. Duplicate id resets startedAt and durationMs, clears any paused state.
    function register(id, durationMs) {
        var restarted = _timers.hasOwnProperty(id)
        _timers[id] = { durationMs: durationMs, startedAt: Date.now() }
        if (!tickTimer.running) tickTimer.start()
        if (restarted)
            console.log("[LocalTimerProcess] restarted:", id, durationMs + "ms")
        else
            console.log("[LocalTimerProcess] registered:", id, durationMs + "ms")
    }

    // Freeze a running timer. remaining() returns the frozen value while paused.
    function pause(id) {
        if (!_timers.hasOwnProperty(id)) {
            console.warn("[LocalTimerProcess] pause: unknown id '" + id + "'")
            return
        }
        var t = _timers[id]
        if (t.pausedRemaining !== undefined) return
        var rem = Math.max(0, t.durationMs - (Date.now() - t.startedAt))
        _timers[id] = { durationMs: t.durationMs, startedAt: t.startedAt, pausedRemaining: rem }
        console.log("[LocalTimerProcess] paused:", id, "remaining:", rem + "ms")
        root.timerPaused(id)
    }

    // Resume a paused timer from where it left off.
    function resume(id) {
        if (!_timers.hasOwnProperty(id)) {
            console.warn("[LocalTimerProcess] resume: unknown id '" + id + "'")
            return
        }
        var t = _timers[id]
        if (t.pausedRemaining === undefined) return
        var newStartedAt = Date.now() - (t.durationMs - t.pausedRemaining)
        _timers[id] = { durationMs: t.durationMs, startedAt: newStartedAt }
        console.log("[LocalTimerProcess] resumed:", id, "remaining:", t.pausedRemaining + "ms")
        root.timerResumed(id)
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

    // Returns "started" | "paused" | null (null = not found or completed).
    function status(id) {
        if (!_timers.hasOwnProperty(id)) return null
        return _timers[id].pausedRemaining !== undefined ? "paused" : "started"
    }

    // Milliseconds elapsed. For paused timers: durationMs - pausedRemaining. Returns 0 if not found.
    function elapsed(id) {
        if (!_timers.hasOwnProperty(id)) return 0
        var t = _timers[id]
        if (t.pausedRemaining !== undefined) return t.durationMs - t.pausedRemaining
        return Date.now() - t.startedAt
    }

    // Milliseconds remaining, clamped to 0. For paused timers: returns frozen pausedRemaining.
    function remaining(id) {
        if (!_timers.hasOwnProperty(id)) return 0
        var t = _timers[id]
        if (t.pausedRemaining !== undefined) return t.pausedRemaining
        return Math.max(0, t.durationMs - (Date.now() - t.startedAt))
    }

    Timer {
        id: tickTimer
        interval: 50
        repeat: true
        onTriggered: {
            var now = Date.now()
            // Collect expired ids first to avoid mutating _timers during iteration.
            // Skip paused entries — they do not count down.
            var expired = []
            for (var id in root._timers) {
                var t = root._timers[id]
                if (t.pausedRemaining !== undefined) continue
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
