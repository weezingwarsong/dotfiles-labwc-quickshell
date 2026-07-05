import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property var activePill: null
    property bool shouldShow: false

    screen: Quickshell.screens[0]
    anchors.top: true
    margins.top: Screen.height * 0.01
    exclusiveZone: 0
    color: "transparent"

    implicitWidth: Screen.width * 0.10
    implicitHeight: 24

    visible: shouldShow
    mask: Region {}

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#1a1a1a"

        Loader {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            sourceComponent: activePill ? activePill.visualComponent : null
        }
    }
}
