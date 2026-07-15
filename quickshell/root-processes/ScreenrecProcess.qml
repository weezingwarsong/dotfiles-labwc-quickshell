import QtQuick
import QtCore
import Quickshell.Io

Item {
    id: root

    // ── Public state ──────────────────────────────────────────────────────────
    property bool   recording:         false
    property string lastRecordingPath: ""
    property string lastReplayPath:    ""

    // ── Signals ───────────────────────────────────────────────────────────────
    signal recordingStarted()
    signal recordingStopped(string path)
    signal replaySaved(string path)
    signal recordingError(string reason)

    // ── Public API (called by FifoListener handlers in shell.qml) ────────────
    function startScreen() { _start("screen") }
    function startRegion() { _start("region") }
    function stop()        { _sendCtl("stop")        }
    function saveReplay()  { _sendCtl("save-replay") }

    // ── Internal ──────────────────────────────────────────────────────────────
    property string _dir:       ""
    property string _replayDir: ""
    property string _ctlFifo:   ""
    property string _startMode: ""

    function _start(mode) {
        if (root.recording) {
            console.log("[ScreenrecProcess] already recording, ignoring start:", mode)
            return
        }
        if (_proc.running) {
            console.log("[ScreenrecProcess] process still running, ignoring start:", mode)
            return
        }
        root._startMode = mode
        _proc.running = true
    }

    function _sendCtl(cmd) {
        if (!root.recording) {
            console.log("[ScreenrecProcess] not recording, ignoring ctl:", cmd)
            return
        }
        if (_ctlWriter.running) return   // previous write still in-flight
        _ctlWriter.command = ["sh", "-c", "echo '" + cmd + "' > " + root._ctlFifo]
        _ctlWriter.running = true
    }

    // ── Long-running recording process ────────────────────────────────────────
    Process {
        id: _proc
        command: {
            var args = ["pillbox-screenrec", root._startMode]
            if (root._dir       !== "") { args.push("--dir");        args.push(root._dir)       }
            if (root._replayDir !== "") { args.push("--replay-dir"); args.push(root._replayDir) }
            return args
        }
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                line = line.trim()
                if (line === "screenrec:started") {
                    root.recording = true
                    root.recordingStarted()
                    console.log("[ScreenrecProcess] started")
                } else if (line.startsWith("screenrec:stopped:")) {
                    var path = line.slice(18)
                    root.recording         = false
                    root.lastRecordingPath = path
                    root.recordingStopped(path)
                    console.log("[ScreenrecProcess] stopped:", path)
                } else if (line.startsWith("screenrec:replay:saved:")) {
                    var rpath = line.slice(23)
                    root.lastReplayPath = rpath
                    root.replaySaved(rpath)
                    console.log("[ScreenrecProcess] replay saved:", rpath)
                } else if (line.startsWith("screenrec:error:")) {
                    var msg = line.slice(16)
                    root.recording = false
                    root.recordingError(msg)
                    console.log("[ScreenrecProcess] error:", msg)
                }
            }
        }

        onExited: function(code, signal) {
            if (root.recording) {
                root.recording = false
                console.log("[ScreenrecProcess] process exited unexpectedly:", code)
            }
        }
    }

    // ── One-shot CTL FIFO writer ──────────────────────────────────────────────
    Process {
        id: _ctlWriter
        running: false
        onExited: function(code, signal) {
            if (code !== 0)
                console.log("[ScreenrecProcess] ctl write failed:", code)
        }
    }

    Component.onCompleted: {
        var home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
                       .toString().replace(/^file:\/\//, "")
        root._dir       = Prefs.recordingDir !== ""
            ? Prefs.recordingDir
            : home + "/.config/pillbox/media/Recordings"
        root._replayDir = Prefs.replayDir !== ""
            ? Prefs.replayDir
            : home + "/.config/pillbox/media/Replays"
        root._ctlFifo   = home + "/.local/share/pillbox/screenrec-ctl"
        console.log("[ScreenrecProcess] started | dir:", root._dir)
    }
}
