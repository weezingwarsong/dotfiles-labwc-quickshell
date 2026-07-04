import QtQuick

Item {
    id: root

    // Injected by shell.qml
    property var clockProcess: null
    property var calendarProcess: null
    property var timerProcess: null

    // ── Reveal conditions (content-driven only) ──────────────────────────────
    // User-initiated triggers (hover, FIFO peek) live in PillController, not here.

    readonly property bool _calendarImminent: {
        if (!calendarProcess || !calendarProcess.nextEvent) return false
        var eventTime = new Date(calendarProcess.nextEvent.start)
        var diffMs = eventTime - (clockProcess ? clockProcess.now : new Date())
        return diffMs > 0 && diffMs <= 10 * 60 * 1000
    }

    readonly property bool _timerActive: timerProcess ? timerProcess.active : false

    readonly property bool shouldShow: _calendarImminent || _timerActive

    // ── Display text ─────────────────────────────────────────────────────────

    readonly property string displayText: {
        if (_timerActive && timerProcess) return timerProcess.displayText
        if (clockProcess) return clockProcess.displayTime
        return "--:--"
    }

    // ── Logging ──────────────────────────────────────────────────────────────

    onShouldShowChanged: console.log("[TimePill] shouldShow:", shouldShow,
        "| calendarImminent:", _calendarImminent, "| timerActive:", _timerActive)

    Component.onCompleted: console.log("[TimePill] started")
}
