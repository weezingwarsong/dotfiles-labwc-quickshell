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

    function notifyExternalSave(path) {
        var name = path.split("/").pop()
        var updated = root.screenshots.slice()
        updated.unshift({ path: path, name: name, timestamp: Date.now() })
        root.screenshots = updated
        root.lastPath = path
        root.screenshotSaved(path)
        console.log("[ScreenshotProcess] external save notified:", path)
    }

    function deleteScreenshot(path) {
        root.screenshots = root.screenshots.filter(function(s) { return s.path !== path })
        root._deletePath = path
        _deleteProc.running = true
    }

    // ── Internal ──────────────────────────────────────────────────────────────
    property string _dir:        ""   // resolved in onCompleted from Prefs or default
    property string _mode:       ""
    property string _deletePath: ""

    function _launch(mode) {
        if (_proc.running) {
            console.log("[ScreenshotProcess] busy, ignoring:", mode)
            return
        }
        root._mode = mode
        _proc.running = true
    }

    Process {
        id: _scanProc
        command: ["sh", "-c",
            "find -L \"$1\" -maxdepth 1 -type f -name '*.png' -printf '%T@\\t%p\\n' 2>/dev/null",
            "sh", root._dir]
        stdout: StdioCollector {
            onStreamFinished: {
                var entries = []
                text.split("\n").forEach(function(line) {
                    line = line.trim()
                    if (line === "" || !line.includes("\t")) return
                    var tab  = line.indexOf("\t")
                    var ts   = parseFloat(line.slice(0, tab)) * 1000
                    var path = line.slice(tab + 1)
                    entries.push({ path: path, name: path.split("/").pop(), timestamp: ts })
                })
                entries.sort(function(a, b) { return b.timestamp - a.timestamp })
                root.screenshots = entries.slice(0, 200)
                console.log("[ScreenshotProcess] scanned:", entries.length, "screenshots in", root._dir)
            }
        }
        onExited: function(code, signal) {
            if (code !== 0)
                console.log("[ScreenshotProcess] scan failed:", code, "dir:", root._dir)
        }
    }

    Process {
        id: _deleteProc
        command: ["rm", "-f", root._deletePath]
        onExited: function(code, signal) {
            _deleteProc.running = false
            if (code !== 0)
                console.log("[ScreenshotProcess] delete failed:", root._deletePath)
        }
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
            _proc.running = false
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
        _scanProc.running = true
    }
}
