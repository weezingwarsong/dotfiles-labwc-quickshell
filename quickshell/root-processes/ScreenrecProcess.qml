import QtQuick
import QtCore
import Quickshell.Io

Item {
    id: root

    // ── Public state ──────────────────────────────────────────────────────────
    // recMode is driven by Prefs — switching while active is blocked in the UI.
    readonly property string recMode: Prefs.recMode !== "" ? Prefs.recMode : "oneshot"

    property bool   active:    false   // script process is alive
    property bool   recording: false   // currently writing to file
                                       // oneshot: same as active
                                       // replay:  true only during toggleRec recording-to-file

    property string lastRecordingPath: ""
    property string lastReplayPath:    ""

    // ── Signals ───────────────────────────────────────────────────────────────
    signal recordingStarted()
    signal recordingStopped(string path)
    signal replaySaved(string path)
    signal recordingError(string reason)

    // ── Public API ────────────────────────────────────────────────────────────

    // oneshot: start if idle, stop (save) if active.
    // replay:  send toggleRec (SIGRTMIN) — toggles recording-to-file.
    function toggle() {
        if (root.recMode === "oneshot") {
            if (!root.active) {
                root._regionCoords = ""
                _proc.running = true
            } else {
                _sendCtl("stop")
            }
        } else {
            if (!root.active) return
            _sendCtl("toggleRec")
            root.recording = !root.recording   // optimistic; cleared on screenrec:stopped
        }
    }

    // One-shot region recording — coords come from pillbox-screenrec-region (slurp).
    function startRegionWith(coords) {
        if (root.recMode !== "oneshot" || root.active) return
        root._regionCoords = coords
        _proc.running = true
    }

    // Switch mode. Blocked while active — caller (UI/FIFO) must ensure daemon/recording
    // is stopped first. Switching TO replay starts the daemon immediately.
    function setMode(mode) {
        if (mode !== "oneshot" && mode !== "replay") return
        if (mode === root.recMode) return
        if (root.recording) {
            console.log("[ScreenrecProcess] setMode blocked: recording in progress")
            return
        }
        // Replay daemon running but no casual recording — stop daemon then switch
        if (root.active) _sendCtl("stop")
        Prefs.setRecMode(mode)
        if (mode === "replay") _proc.running = true
    }

    function saveReplay()         { _sendCtl("saveReplay") }
    function saveReplaySeconds(n) { _sendCtl("saveReplay:" + n) }
    function pause()              { _sendCtl("pause") }
    function emergencyStop()      { _sendCtl("stop") }

    // ── Internal ──────────────────────────────────────────────────────────────
    property string _dir:          ""
    property string _replayDir:    ""
    property string _ctlFifo:      ""
    property string _regionCoords: ""

    function _sendCtl(cmd) {
        if (!root.active) {
            console.log("[ScreenrecProcess] not active, ignoring ctl:", cmd)
            return
        }
        if (_ctlWriter.running) return
        _ctlWriter.command = ["sh", "-c",
            "printf '%s\\n' \"$1\" > \"$2\"", "sh", cmd, root._ctlFifo]
        _ctlWriter.running = true
    }

    // ── Long-running process ──────────────────────────────────────────────────
    Process {
        id: _proc
        command: {
            var mode = root.recMode
            var args = ["pillbox-screenrec", mode]
            args.push("--fps");   args.push(Prefs.recordingFps)
            args.push("--audio"); args.push(Prefs.recAudio !== "" ? Prefs.recAudio : "none")
            if (root._dir !== "") {
                args.push("--dir"); args.push(root._dir)
            }
            if (mode === "replay") {
                args.push("--replay-secs"); args.push(Prefs.replayBufferSecs)
                if (root._replayDir !== "") {
                    args.push("--replay-dir"); args.push(root._replayDir)
                }
            }
            if (mode === "oneshot" && root._regionCoords !== "") {
                args.push("--source"); args.push("region")
                args.push("--region"); args.push(root._regionCoords)
            }
            return args
        }
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                line = line.trim()
                if (line === "screenrec:started") {
                    root.active = true
                    if (root.recMode === "oneshot") root.recording = true
                    root.recordingStarted()
                    console.log("[ScreenrecProcess] started, mode:", root.recMode)
                } else if (line.startsWith("screenrec:stopped:")) {
                    var path = line.slice(18)
                    root.recording = false
                    if (root.recMode === "oneshot") root.active = false
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
            root.active    = false
            root.recording = false
            if (code !== 0)
                console.log("[ScreenrecProcess] exited unexpectedly:", code)
        }
    }

    // ── CTL FIFO writer ───────────────────────────────────────────────────────
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
        console.log("[ScreenrecProcess] init | mode:", root.recMode, "| dir:", root._dir)

        if (root.recMode === "replay")
            _proc.running = true
    }
}
