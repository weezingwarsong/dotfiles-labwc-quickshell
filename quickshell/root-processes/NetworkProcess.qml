import QtQuick
import Quickshell.Io

Item {
    id: root

    property string localIp:   ""
    property bool   connected: false

    // ── Public API ────────────────────────────────────────────────────────────

    function poll() {
        if (!_ipProc.running) _ipProc.running = true
    }

    function toggleNetworking() {
        root._nmAction = root.connected ? "off" : "on"
        _toggleProc.running = true
    }

    // ── IP poll ───────────────────────────────────────────────────────────────
    // "ip -4 route get 1.1.1.1" returns the source IP of the interface used for
    // outbound traffic — the address you'd share for LAN games. Fails/empty when
    // there is no route (disconnected).

    Process {
        id: _ipProc
        command: ["ip", "-4", "route", "get", "1.1.1.1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var match = text.match(/\bsrc\s+(\S+)/)
                root.localIp   = match ? match[1] : ""
                root.connected = !!match
            }
        }
    }

    // ── Toggle ────────────────────────────────────────────────────────────────

    property string _nmAction: "on"

    Process {
        id: _toggleProc
        command: ["nmcli", "networking", root._nmAction]
        onExited: Qt.callLater(root.poll)
    }

    // ── Poll timer ────────────────────────────────────────────────────────────

    Timer {
        interval: 30000
        repeat:   true
        running:  true
        onTriggered: root.poll()
    }

    Component.onCompleted: poll()
}
