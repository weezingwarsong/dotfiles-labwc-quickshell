import QtQuick
import Quickshell.Io

Item {
    id: root

    readonly property real cpuValue:  _cpu  / 100.0
    readonly property real memValue:  _mem  / 100.0
    readonly property real gpuValue:  _gpu  / 100.0
    readonly property real diskValue: _disk / 100.0

    property int _cpu:  0
    property int _mem:  0
    property int _gpu:  0
    property int _disk: 0

    Process {
        id: _proc
        command: ["pillbox-sysmon"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                line.trim().split(" ").forEach(function(tok) {
                    var kv = tok.split(":")
                    if (kv.length !== 2) return
                    var v = parseInt(kv[1])
                    if      (kv[0] === "cpu")  root._cpu  = v
                    else if (kv[0] === "mem")  root._mem  = v
                    else if (kv[0] === "gpu")  root._gpu  = v
                    else if (kv[0] === "disk") root._disk = v
                })
            }
        }
        onExited: function(code, signal) {
            console.log("[SystemProcess] sysmon exited, restarting in 2s")
            _restartTimer.restart()
        }
    }

    Timer {
        id: _restartTimer
        interval: 2000
        onTriggered: _proc.running = true
    }
}
