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

    readonly property bool _urgentCountdown: timerProcess !== null
        && timerProcess.mode === "timer"
        && timerProcess.active
        && timerProcess._remainMs > 0
        && timerProcess._remainMs < 10000

    readonly property int  priority:     (_calendarImminent || _timerActive) ? 10 : 1
    readonly property bool shouldReveal: _calendarImminent || _timerActive

    // ── Display text ─────────────────────────────────────────────────────────

    readonly property string displayText: {
        if (_timerActive && timerProcess) return timerProcess.displayText
        if (clockProcess) return clockProcess.displayTime
        return "--:--"
    }

    readonly property string _calendarText: {
        if (!_calendarImminent || !calendarProcess || !calendarProcess.nextEvent) return ""
        var eventTime = new Date(calendarProcess.nextEvent.start)
        var diffMs = eventTime - (clockProcess ? clockProcess.now : new Date())
        var minutes = Math.max(1, Math.ceil(diffMs / 60000))
        return calendarProcess.nextEvent.summary + " in " + minutes + "m"
    }

    // ── Visual component ─────────────────────────────────────────────────────

    // bgColor override: PillWindow uses this when defined to replace pillBgColor.
    readonly property color bgColor: _urgentCountdown
        ? Style.criticalBgColor
        : (_calendarImminent && !_timerActive ? Style.accentBgColor : Style.pillBgColor)

    property Component visualComponent: Component {
        Item {
            id: vc
            readonly property bool _showScroll: root._calendarImminent && !root._timerActive
            implicitWidth:  _showScroll ? _scrollLabel.implicitWidth : simpleText.implicitWidth
            implicitHeight: Style.fontSizePill

            Text {
                id: simpleText
                anchors.centerIn: parent
                visible: !vc._showScroll
                text: root._urgentCountdown
                    ? root.displayText + (root.timerProcess ? root.timerProcess.displayCenti : "")
                    : root.displayText
                color: root._urgentCountdown ? Style.textCritical : Style.textPrimary
                font.pixelSize: Style.fontSizePill
                font.family: Style.fontMono
            }

            ScrollingText {
                id: _scrollLabel
                visible: vc._showScroll
                anchors.centerIn: parent
                width: implicitWidth
                text: root._calendarText
                color: Style.textPrimary
                font.pixelSize: Style.fontSizePill
                font.family: Style.fontMono
                maxWidth: 200
            }
        }
    }

    // ── Logging ──────────────────────────────────────────────────────────────

    onShouldRevealChanged: console.log("[TimePill] shouldReveal:", shouldReveal,
        "| priority:", priority, "| calendarImminent:", _calendarImminent, "| timerActive:", _timerActive)

    Component.onCompleted: console.log("[TimePill] started")
}
