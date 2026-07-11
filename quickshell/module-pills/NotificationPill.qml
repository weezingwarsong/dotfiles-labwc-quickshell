import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    property var notificationServer: null

    // ── Priority interface (read by PillController) ───────────────────────────

    readonly property bool _hasCritical: notificationServer ? notificationServer.countCritical > 0 : false
    readonly property bool _hasAny:      notificationServer ? notificationServer.countTotal > 0 : false

    property bool _peeking:         false  // normal peek — 7s
    property bool _peekingCritical: false  // critical peek — 10s, beats all

    // Normal peek: 6 (beats MprisPill 5, yields to WorkspacePill 100 / WindowPill 200)
    // Critical peek: 1000 (beats everything)
    readonly property int  priority: {
        if (_peekingCritical && _hasAny) return 1000
        if (_peeking && _hasAny)         return 6
        return 0
    }
    readonly property bool shouldReveal: (_peeking || _peekingCritical) && _hasAny

    Connections {
        target: notificationServer
        enabled: notificationServer !== null
        function onNewNotification(notif) {
            if (notif && notif.urgency === NotificationUrgency.Critical) {
                root._peekingCritical = true
                _criticalPeekTimer.restart()
            }
            root._peeking = true
            _peekTimer.restart()
        }
    }

    Timer {
        id: _peekTimer
        interval: 7000
        onTriggered: root._peeking = false
    }

    Timer {
        id: _criticalPeekTimer
        interval: 10000
        onTriggered: root._peekingCritical = false
    }

    // ── Visual component ──────────────────────────────────────────────────────

    // Critical background while critical notifications are present and pill is visible
    readonly property color bgColor: _hasCritical ? Style.criticalBgColor : Style.pillBgColor

    readonly property string _displayText: {
        if (!notificationServer || notificationServer.countTotal === 0) return ""
        var total    = notificationServer.countTotal
        var critical = notificationServer.countCritical
        return critical > 0 ? (total + " !" + critical) : ("" + total)
    }

    property Component visualComponent: Component {
        Text {
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text:           root._displayText
            color:          root._hasCritical ? Style.textCritical : Style.textPrimary
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
