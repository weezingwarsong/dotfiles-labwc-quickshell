pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io

Item {
    id: root

    // All md3 semantic roles from matugen, keyed by snake_case name.
    // Updated by WallpaperProcess after each matugen run via apply().
    readonly property var md3: _md3
    property var _md3: ({})

    // Called by WallpaperProcess after matugen exits to push new colors in.
    function apply(jsonText) {
        if (!jsonText || jsonText.length < 2) return
        try {
            root._md3 = JSON.parse(jsonText).md3 || {}
            console.log("[Colors] loaded", Object.keys(root._md3).length, "md3 roles")
        } catch(e) {
            console.log("[Colors] parse error:", e)
        }
    }

    // Load last extracted palette on startup (if colors.json already exists).
    Process {
        id: _initReadProc
        command: ["cat", root._colorsPath]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
    }

    property string _colorsPath: ""

    Component.onCompleted: {
        var home = StandardPaths.writableLocation(StandardPaths.HomeLocation)
            .toString().replace(/^file:\/\//, "")
        root._colorsPath = home + "/.local/state/quickshell/generated/colors.json"
        _initReadProc.running = true
    }
}
