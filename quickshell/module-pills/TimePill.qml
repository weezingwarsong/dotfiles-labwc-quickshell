import QtQuick
import Quickshell

Item {
    id: root

    // Injected by shell.qml
    property var clockProcess: null
    property var calendarProcess: null
    property var timerProcess: null

    // ── Priority interface (read by PillController) ───────────────────────────

    readonly property bool _calendarImminent: {
        if (!calendarProcess || !calendarProcess.nextEvent) return false
        var eventTime = new Date(calendarProcess.nextEvent.start)
        var diffMs = eventTime - (clockProcess ? clockProcess.now : new Date())
        return diffMs > 0 && diffMs <= 10 * 60 * 1000
    }

    readonly property bool _timerActive: timerProcess ? timerProcess.active : false

    readonly property int  priority:     (_calendarImminent || _timerActive) ? 10 : 1
    readonly property bool shouldReveal: _calendarImminent || _timerActive

    // ── Display text ─────────────────────────────────────────────────────────

    readonly property string displayText: {
        if (_timerActive && timerProcess) return timerProcess.displayText
        if (clockProcess) return clockProcess.displayTime
        return "--:--"
    }

    // ── Visual component ─────────────────────────────────────────────────────

    property Component visualComponent: Component {
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.displayText
            color: Style.textPrimary
            font.pixelSize: Style.pillTextSize
            font.family: Style.fontMono
        }
    }

    // ── Logging ──────────────────────────────────────────────────────────────

    onShouldRevealChanged: console.log("[TimePill] shouldReveal:", shouldReveal,
        "| priority:", priority, "| calendarImminent:", _calendarImminent, "| timerActive:", _timerActive)

    Component.onCompleted: console.log("[TimePill] started")
}
