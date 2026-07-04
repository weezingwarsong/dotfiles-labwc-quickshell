import QtQuick

Item {
    id: root

    property string displayTime: Qt.formatTime(new Date(), "HH:mm")
    property string displayTimeFull: Qt.formatTime(new Date(), "HH:mm:ss")
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.now = new Date()
            root.displayTime = Qt.formatTime(root.now, "HH:mm")
            root.displayTimeFull = Qt.formatTime(root.now, "HH:mm:ss")
            console.log("[ClockProcess]", root.displayTimeFull)
        }
    }

    Component.onCompleted: console.log("[ClockProcess] started:", root.displayTimeFull)
}
