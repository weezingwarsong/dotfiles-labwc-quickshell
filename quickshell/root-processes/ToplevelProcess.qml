import QtQuick
import Quickshell.Wayland

Item {
    id: root

    // ── Outputs ───────────────────────────────────────────────────────────────
    readonly property var windows: ToplevelManager.toplevels        // ObjectModel<Toplevel>
    readonly property var focused: ToplevelManager.activeToplevel   // native active tracking

    // ── Logging ───────────────────────────────────────────────────────────────

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() {
            var t = ToplevelManager.activeToplevel
            console.log("[ToplevelProcess] activeToplevel →",
                t ? t.appId + " | " + t.title : "none")
        }
    }

    // One delegate per toplevel — purely for add/remove logging and validation.
    Instantiator {
        model: ToplevelManager.toplevels
        delegate: QtObject {
            required property var modelData
            Component.onCompleted: console.log("[ToplevelProcess] window added:",
                modelData.appId, "|", modelData.title)
            Component.onDestruction: console.log("[ToplevelProcess] window removed:",
                modelData.appId, "|", modelData.title)
        }
    }

    Component.onCompleted: {
        var vals = ToplevelManager.toplevels.values
        var active = ToplevelManager.activeToplevel
        console.log("[ToplevelProcess] started. Windows:", vals ? vals.length : "?",
            "| Active:", active ? active.appId : "none")
        if (vals) {
            for (var i = 0; i < vals.length; i++)
                console.log("[ToplevelProcess]  [" + i + "]", vals[i].appId, "|", vals[i].title)
        }
    }
}
