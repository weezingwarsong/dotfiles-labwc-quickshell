import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    property var screenshotProcess:  null
    property var screenrecProcess:   null
    property var notificationServer: null

    readonly property bool   screenshotPreviewActive:   _ssLoader.item ? _ssLoader.item._showPreview : false
    readonly property string screenshotPreviewPath:     _ssLoader.item ? _ssLoader.item._path        : ""
    readonly property string screenshotPreviewFilename: _ssLoader.item ? _ssLoader.item._filename    : ""

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
             (_ntLoader.item ? _ntLoader.item.shouldShow : false) ||
             (_utLoader.item ? _utLoader.item.shouldShow : false) ||
             (_srLoader.item ? _srLoader.item.shouldShow : false)

    function dismiss(id) {
        if (id === "screenshot"   && _ssLoader.item) _ssLoader.item._dismiss()
        if (id === "notification" && _ntLoader.item) _ntLoader.item._dismiss()
        if (id === "critical"     && _utLoader.item) _utLoader.item._dismiss()
        if (id === "screenrec"    && _srLoader.item) _srLoader.item._dismiss()
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 6

        // ScreenshotPreview — transient, sits above the others
        Loader {
            id: _ssLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/ScreenshotPreview.qml")
            onLoaded: item.screenshotProcess = Qt.binding(function() { return root.screenshotProcess })
        }

        // NotificationToast — Normal/Low/Transient, index 2
        Loader {
            id: _ntLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/NotificationToast.qml")
            onLoaded: {
                item.notificationServer = Qt.binding(function() { return root.notificationServer })
            }
        }

        // CriticalNotificationToast — Critical urgency only, index 1, closer to corner
        Loader {
            id: _utLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/CriticalNotificationToast.qml")
            onLoaded: item.notificationServer = Qt.binding(function() { return root.notificationServer })
        }

        // ScreenrecToast — index 0, closest to screen corner
        Loader {
            id: _srLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/ScreenrecToast.qml")
            onLoaded: item.screenrecProcess = Qt.binding(function() { return root.screenrecProcess })
        }
    }
}
