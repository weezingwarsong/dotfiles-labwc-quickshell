import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Dumb container for toast modules. Bottom-right corner, stacks vertically.
// Index 0 (ScreenshotPreview) at top, index 1 (ScreenrecToast) at bottom.
// Deviation from plan: ToastController is not separately instantiated in shell.qml;
// visible is computed directly from the loaded items' shouldShow properties.
PanelWindow {
    id: root

    property var screenshotProcess: null
    property var screenrecProcess:  null

    screen:         Quickshell.screens[0]
    anchors.bottom: true
    anchors.right:  true
    margins.bottom: Screen.height * 0.02
    margins.right:  Screen.height * 0.02
    exclusiveZone:  0
    color:          "transparent"

    implicitWidth:  Math.round(Screen.width * 0.15)
    implicitHeight: _col.implicitHeight
    mask: Region { item: _col }

    visible: (_ssLoader.item ? _ssLoader.item.shouldShow : false) ||
             (_srLoader.item  ? _srLoader.item.shouldShow  : false)

    function dismiss(id) {
        if (id === "screenshot" && _ssLoader.item) _ssLoader.item._dismiss()
        if (id === "screenrec"  && _srLoader.item) _srLoader.item._dismiss()
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 6

        // Index 0 — ScreenshotPreview (transient, above ScreenrecToast)
        Loader {
            id: _ssLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/ScreenshotPreview.qml")
            onLoaded: item.screenshotProcess = Qt.binding(function() { return root.screenshotProcess })
        }

        // Index 1 — ScreenrecToast (persistent during recording, bottom/corner anchor)
        Loader {
            id: _srLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/ScreenrecToast.qml")
            onLoaded: item.screenrecProcess = Qt.binding(function() { return root.screenrecProcess })
        }
    }
}
