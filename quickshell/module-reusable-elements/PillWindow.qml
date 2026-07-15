import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property var activePill: null
    property bool shouldShow: false

    screen: Quickshell.screens[0]
    anchors.top: true
    margins.top: Screen.height * 0.02
    exclusiveZone: 0
    color: "transparent"

    implicitWidth: (contentLoader.item ? contentLoader.item.implicitWidth : 0) + 40
    implicitHeight: (contentLoader.item ? contentLoader.item.implicitHeight : Style.fontSizePill) + Style.pillPaddingV

    visible: shouldShow
    mask: Region {}

    Rectangle {
        anchors.fill: parent
        radius: Style.pillRadius
        color: (activePill && activePill.bgColor) ? activePill.bgColor : Style.pillBgColor
        border.color: Style.borderFaintColor
        border.width: Style.pillBorderWidth

        Loader {
            id: contentLoader
            anchors.centerIn: parent
            width: item ? item.implicitWidth : 0
            height: parent.height
            sourceComponent: activePill ? activePill.visualComponent : null
        }
    }
}
