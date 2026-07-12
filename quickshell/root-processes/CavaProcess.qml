import QtQuick
import Quickshell.Io

Item {
    id: root

    property var  bars:   []
    property bool active: true

    property var _smooth: []

    onActiveChanged: if (!active) { bars = []; _smooth = [] }

    Process {
        id: cava
        command: ["bash", "-c", "cava -p \"${HOME}/.config/pillbox/cava.conf\""]
        running: root.active
        stdout: SplitParser {
            onRead: function(line) {
                var trimmed = line.trim()
                if (trimmed.length === 0) return
                if (trimmed.endsWith(";")) trimmed = trimmed.slice(0, -1)
                var parts = trimmed.split(";")
                if (parts.length < 2) return

                var raw = new Array(parts.length)
                for (var i = 0; i < parts.length; i++)
                    raw[i] = parseInt(parts[i]) / 1000.0

                if (root._smooth.length !== raw.length) {
                    root._smooth = raw.slice()
                } else {
                    var s = root._smooth.slice()
                    for (var j = 0; j < raw.length; j++)
                        s[j] = s[j] * 0.65 + raw[j] * 0.35
                    root._smooth = s
                }
                root.bars = root._smooth.slice()
            }
        }
        onExited: function(code, signal) {
            if (root.active) restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: { if (root.active) cava.running = true }
    }

    Component.onCompleted: console.log("[CavaProcess] initialized")
}
