import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    signal newNotification(var notif)

    NotificationServer {
        id: _server
        keepOnReload:         false
        bodySupported:        true
        actionsSupported:     true
        imageSupported:       true
        persistenceSupported: false

        onNotification: function(notif) {
            if (!notif.transient) notif.tracked = true
            root._timestamps[notif.id] = new Date()
            root._tsVersion++
            Qt.callLater(root._recalc)
            root.newNotification(notif)
            var actIds = []
            if (notif.actions) for (var i = 0; i < notif.actions.length; i++) actIds.push(notif.actions[i].identifier + "=" + notif.actions[i].text)
            console.log("[NotificationServer] received:", notif.appName, "|", notif.summary,
                "| urgency:", notif.urgency, "| actions:", JSON.stringify(actIds))
        }
    }

    // Model for panel Repeater — UntypedObjectModel backed by D-Bus server
    readonly property var notifications: _server.trackedNotifications

    // Counts — updated by _recalc()
    property int countTotal:    0
    property int countCritical: 0

    // Timestamp storage — keyed by notification id
    property int _tsVersion: 0
    property var _timestamps: ({})

    function getTimestamp(notifId) {
        _tsVersion  // reactive dependency — forces re-eval when timestamps update
        return _timestamps[notifId] || null
    }

    function clearAll() {
        if (!_server.trackedNotifications) return
        var notifs = _server.trackedNotifications.values.slice()
        for (var i = 0; i < notifs.length; i++) {
            notifs[i].dismiss()
        }
        Qt.callLater(_recalc)
    }

    function _recalc() {
        if (!_server.trackedNotifications) {
            countTotal    = 0
            countCritical = 0
            return
        }
        var notifs   = _server.trackedNotifications.values
        var critical = 0
        for (var i = 0; i < notifs.length; i++) {
            if (notifs[i].urgency === NotificationUrgency.Critical) critical++
        }
        countTotal    = notifs.length
        countCritical = critical
        console.log("[NotificationServer] recalc: total=" + countTotal + " critical=" + countCritical)
    }

    Connections {
        target: _server
        function onTrackedNotificationsChanged() { root._recalc() }
    }

    Component.onCompleted: console.log("[NotificationServer] started, replacing system notification daemon")
}
