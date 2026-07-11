import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    property var notificationServer: null

    // ── Priority interface (read by PillController) ───────────────────────────

    readonly property bool _hasCritical: notificationServer ? notificationServer.countCritical > 0 : false
    readonly property bool _hasAny:      notificationServer ? notificationServer.countTotal > 0 : false

    property bool _peeking: false

    // Priority: 2 during 7s peek window (beats TimePill at 1), 0 otherwise
    readonly property int  priority:     (_peeking && _hasAny) ? 2 : 0
    readonly property bool shouldReveal: (_peeking && _hasAny)

    Connections {
        target: notificationServer
        enabled: notificationServer !== null
        function onNewNotification() {
            root._peeking = true
            _peekTimer.restart()
        }
    }

    Timer {
        id: _peekTimer
        interval: 7000
        onTriggered: root._peeking = false
    }

    // ── Visual component ──────────────────────────────────────────────────────

    // Red background while critical notifications are present and pill is visible
    readonly property color bgColor: _hasCritical
        ? Qt.darker(Style.color11, 1.5)
        : Style.pillBgColor

    readonly property string _displayText: {
        if (!notificationServer || notificationServer.countTotal === 0) return ""
        var total    = notificationServer.countTotal
        var critical = notificationServer.countCritical
        return critical > 0 ? (total + " | " + critical) : ("" + total)
    }

    property Component visualComponent: Component {
        Text {
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text:           root._displayText
            color:          Style.textPrimary
            font.family:    Style.fontMono
            font.pixelSize: Style.fontSizePill
        }
    }

    // ── Logging ───────────────────────────────────────────────────────────────

    onPriorityChanged:     console.log("[NotificationPill] priority:", priority,
        "| total:", notificationServer ? notificationServer.countTotal : 0,
        "| critical:", notificationServer ? notificationServer.countCritical : 0)
    onShouldRevealChanged: console.log("[NotificationPill] shouldReveal:", shouldReveal)
    Component.onCompleted: console.log("[NotificationPill] started")
}
