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

    implicitWidth: (contentLoader.item ? contentLoader.item.implicitWidth : 0) + 40
    implicitHeight: 24

    visible: shouldShow
    mask: Region {}

    Rectangle {
        anchors.fill: parent
        radius: Style.pillBorderRadius
        color: Style.pillBgColor

        Loader {
            id: contentLoader
            anchors.centerIn: parent
            width: item ? item.implicitWidth : 0
            height: parent.height
            sourceComponent: activePill ? activePill.visualComponent : null
        }
    }
}
