import QtQuick

Item {
    id: root

    // Injected by shell.qml
    property var clockProcess: null
    property var calendarProcess: null
    property var timerProcess: null

    // ── Reveal conditions ────────────────────────────────────────────────────────

    property bool _manualPeek: false

    readonly property bool _calendarImminent: {
        if (!calendarProcess || !calendarProcess.nextEvent) return false
        var eventTime = new Date(calendarProcess.nextEvent.start)
        var diffMs = eventTime - (clockProcess ? clockProcess.now : new Date())
        return diffMs > 0 && diffMs <= 10 * 60 * 1000
    }

    readonly property bool _timerActive: timerProcess ? timerProcess.active : false

    readonly property bool shouldShow: _manualPeek || _calendarImminent || _timerActive

    // ── Display text ─────────────────────────────────────────────────────────────

    readonly property string displayText: {
        if (_timerActive && timerProcess) return timerProcess.displayText
        if (clockProcess) return clockProcess.displayTime
        return "--:--"
    }

    // ── Manual peek ──────────────────────────────────────────────────────────────

    function triggerManualPeek() {
        _manualPeek = true
        peekTimer.restart()
        console.log("[TimePill] manual peek triggered")
    }

    Timer {
        id: peekTimer
        interval: 5000
        onTriggered: {
            root._manualPeek = false
            console.log("[TimePill] manual peek expired")
        }
    }

    // ── Logging ──────────────────────────────────────────────────────────────────

    onShouldShowChanged: console.log("[TimePill] shouldShow:", shouldShow, "| text:", displayText,
        "| manualPeek:", _manualPeek, "| calendarImminent:", _calendarImminent, "| timerActive:", _timerActive)

    onDisplayTextChanged: {
        if (shouldShow) console.log("[TimePill] displayText:", displayText)
    }

    Component.onCompleted: console.log("[TimePill] started")
}
