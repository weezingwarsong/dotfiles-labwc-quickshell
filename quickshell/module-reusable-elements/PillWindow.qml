import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property var activePill: null
    property bool shouldShow: false

    screen: Quickshell.screens[0]
    anchors.top: true
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

        Text {
            anchors.centerIn: parent
            text: activePill ? activePill.displayText : ""
            color: "#ffffff"
            font.pixelSize: 13
            font.family: "monospace"
        }
    }
}
