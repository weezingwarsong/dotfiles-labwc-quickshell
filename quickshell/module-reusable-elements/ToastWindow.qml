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

    visible: (_srReplayLoader.item ? _srReplayLoader.item.shouldShow : false) ||
             (_srSavedLoader.item ? _srSavedLoader.item.shouldShow : false) ||
             (_srRecLoader.item   ? _srRecLoader.item.shouldShow   : false) ||
             (_ssLoader.item      ? _ssLoader.item.shouldShow      : false) ||
             (_ntLoader.item      ? _ntLoader.item.shouldShow      : false) ||
             (_utLoader.item      ? _utLoader.item.shouldShow      : false)

    function dismiss(id) {
        if (id === "screenshot"   && _ssLoader.item) _ssLoader.item._dismiss()
        if (id === "notification" && _ntLoader.item) _ntLoader.item._dismiss()
        if (id === "critical"     && _utLoader.item) _utLoader.item._dismiss()
        if (id === "screenrecSaved" && _srSavedLoader.item) _srSavedLoader.item._dismiss()
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        spacing: 6

        // Replay captured — slot 6, furthest from edge
        Loader {
            id: _srReplayLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/ScreenrecReplayToast.qml")
            onLoaded: item.screenrecProcess = Qt.binding(function() { return root.screenrecProcess })
        }

        // Post recording — slot 5
        Loader {
            id: _srSavedLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/ScreenrecSavedToast.qml")
            onLoaded: item.screenrecProcess = Qt.binding(function() { return root.screenrecProcess })
        }

        // While recording — slot 4
        Loader {
            id: _srRecLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/ScreenrecRecordingToast.qml")
            onLoaded: item.screenrecProcess = Qt.binding(function() { return root.screenrecProcess })
        }

        // Screenshot preview — slot 3
        Loader {
            id: _ssLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/ScreenshotPreview.qml")
            onLoaded: item.screenshotProcess = Qt.binding(function() { return root.screenshotProcess })
        }

        // Normal/Low/Transient notifications — slot 2
        Loader {
            id: _ntLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/NotificationToast.qml")
            onLoaded: item.notificationServer = Qt.binding(function() { return root.notificationServer })
        }

        // Critical notifications — slot 1, nearest to screen corner
        Loader {
            id: _utLoader
            Layout.fillWidth: true
            source: Qt.resolvedUrl("../module-toasts/CriticalNotificationToast.qml")
            onLoaded: item.notificationServer = Qt.binding(function() { return root.notificationServer })
        }
    }
}
