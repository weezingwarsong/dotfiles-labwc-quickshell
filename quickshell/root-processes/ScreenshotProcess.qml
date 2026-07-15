import QtQuick
import QtCore
import Quickshell.Io

Item {
    id: root

    // ── Public state ──────────────────────────────────────────────────────────
    property var    screenshots: []    // [{path, name, timestamp}], newest first
    property string lastPath:    ""    // most recent saved path — toast reads this

    // ── Signals ───────────────────────────────────────────────────────────────
    signal screenshotSaved(string path)
    signal screenshotError(string reason)

    // ── Public API (called by FifoListener handlers in shell.qml) ────────────
    function takeScreen()  { _launch("screen")  }
    function takeAll()     { _launch("all")     }
    function takeRegion()  { _launch("region")  }

    // ── Internal ──────────────────────────────────────────────────────────────
    property string _dir:  ""   // resolved in onCompleted from Prefs or default
    property string _mode: ""

    function _launch(mode) {
        if (_proc.running) {
            console.log("[ScreenshotProcess] busy, ignoring:", mode)
            return
        }
        root._mode = mode
        _proc.running = true
    }

    Process {
        id: _proc
        command: {
            var args = ["pillbox-screenshot", root._mode]
            if (root._dir !== "") { args.push("--dir"); args.push(root._dir) }
            return args
        }
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                line = line.trim()
                if (line.startsWith("screenshot:saved:")) {
                    var path = line.slice(17)
                    root.lastPath = path
                    var name = path.split("/").pop()
                    var updated = root.screenshots.slice()
                    updated.unshift({ path: path, name: name, timestamp: Date.now() })
                    root.screenshots = updated
                    root.screenshotSaved(path)
                    console.log("[ScreenshotProcess] saved:", path)
                } else if (line.startsWith("screenshot:error:")) {
                    var msg = line.slice(17)
                    root.screenshotError(msg)
                    console.log("[ScreenshotProcess] error:", msg)
                }
            }
        }

        onExited: function(code, signal) {
            if (code !== 0)
                console.log("[ScreenshotProcess] script exited", code, "| mode:", root._mode)
        }
    }

    Component.onCompleted: {
        var home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
                       .toString().replace(/^file:\/\//, "")
        root._dir = Prefs.screenshotDir !== ""
            ? Prefs.screenshotDir
            : home + "/.config/pillbox/media/Screenshots"
        console.log("[ScreenshotProcess] started | dir:", root._dir)
    }
}
