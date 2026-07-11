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
            height: parent.height
            readonly property bool _showScroll: root._calendarImminent && !root._timerActive
            implicitWidth: _showScroll
                ? Math.min(scrollText.implicitWidth, 200)
                : simpleText.implicitWidth

            Text {
                id: simpleText
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                visible: !vc._showScroll
                text: root._urgentCountdown
                    ? root.displayText + (root.timerProcess ? root.timerProcess.displayCenti : "")
                    : root.displayText
                color: root._urgentCountdown ? Style.textCritical : Style.textPrimary
                font.pixelSize: Style.fontSizePill
                font.family: Style.fontMono
            }

            Item {
                id: scrollClip
                visible: vc._showScroll
                height: parent.height
                width: vc.implicitWidth
                clip: true

                Text {
                    id: scrollText
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    text: root._calendarText
                    color: Style.textPrimary
                    font.pixelSize: Style.fontSizePill
                    font.family: Style.fontMono

                    onTextChanged: {
                        x = 0
                        scrollAnim.restart()
                    }
                }

                SequentialAnimation {
                    id: scrollAnim
                    running: scrollClip.visible && scrollText.implicitWidth > scrollClip.width
                    loops: Animation.Infinite
                    PauseAnimation { duration: 1500 }
                    NumberAnimation {
                        target: scrollText
                        property: "x"
                        to: -(scrollText.implicitWidth - scrollClip.width)
                        duration: Math.max(1, scrollText.implicitWidth - scrollClip.width) * 20
                        easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation { target: scrollText; property: "x"; to: 0; duration: 0 }
                }
            }
        }
    }

    // ── Logging ──────────────────────────────────────────────────────────────

    onShouldRevealChanged: console.log("[TimePill] shouldReveal:", shouldReveal,
        "| priority:", priority, "| calendarImminent:", _calendarImminent, "| timerActive:", _timerActive)

    Component.onCompleted: console.log("[TimePill] started")
}
