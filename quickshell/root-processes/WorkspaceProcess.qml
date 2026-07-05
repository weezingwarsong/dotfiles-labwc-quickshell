import QtQuick
import Quickshell.WindowManager

Item {
    id: root

    // ── Outputs ───────────────────────────────────────────────────────────────
    property var current: null  // the active Windowset (has .name, .active, .activate())
    readonly property var list: {
        var sets = WindowManager.windowsets
        var names = []
        for (var i = 0; i < sets.length; i++) names.push(sets[i].name)
        return names
    }
    readonly property int currentIndex: {
        if (!current) return -1
        var sets = WindowManager.windowsets
        for (var i = 0; i < sets.length; i++)
            if (sets[i] === current) return i
        return -1
    }

    signal workspaceChanged(var workspace)

    // ── Watch each windowset's active flag ────────────────────────────────────
    // Instantiator creates a watcher per windowset. When a windowset's active
    // flag flips to true, that is the new current workspace.
    Instantiator {
        model: WindowManager.windowsets
        delegate: QtObject {
            required property var modelData
            property var _watch: Connections {
                target: modelData
                function onActiveChanged() {
                    if (modelData.active) {
                        root.current = modelData
                        root.workspaceChanged(modelData)
                        console.log("[WorkspaceProcess] workspace →", modelData.name)
                    }
                }
            }
        }
        onObjectAdded: function(index, object) {
            // Capture initial active workspace as objects are created at startup
            if (object.modelData && object.modelData.active)
                root.current = object.modelData
        }
    }

    Component.onCompleted: {
        var sets = WindowManager.windowsets
        for (var i = 0; i < sets.length; i++) {
            if (sets[i].active) { root.current = sets[i]; break }
        }
        console.log("[WorkspaceProcess] started. Current:", root.current ? root.current.name : "none",
            "| Workspaces:", root.list.join(", "))
    }
}
