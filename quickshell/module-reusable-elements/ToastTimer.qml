import QtQuick

// Auto-dismiss timer with hover-pause. Bind `paused` to a HoverHandler.hovered.
// On unpause (mouse leave), always restarts from the full interval — no resume.
QtObject {
    id: root

    property int  interval: 5000
    property bool running:  false
    property bool paused:   false

    signal expired()

    onRunningChanged: running ? _t.restart() : _t.stop()
    onPausedChanged:  paused  ? _t.stop()    : (running ? _t.restart() : undefined)

    property Timer _t: Timer {
        interval: root.interval
        repeat:   false
        onTriggered: {
            root.running = false
            root.expired()
        }
    }
}
