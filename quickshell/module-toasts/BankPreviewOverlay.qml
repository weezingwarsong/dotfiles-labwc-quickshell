import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    property string imagePath: ""

    screen: Quickshell.screens[0]
    anchors.right: true
    anchors.top:   true

    // Sit to the left of the panel; align with panel top
    WlrLayershell.margins {
        right: Math.round(Screen.width * (1 + Style.panelWidth / 100) / 2) + 8
        top:   Math.round(Screen.width * Style.panelOffsetY / 100)
    }
    WlrLayershell.layer: WlrLayer.Overlay

    exclusiveZone: 0
    color:         "transparent"
    visible:       root.imagePath !== ""
    mask: Region { }

    implicitWidth:  Math.round(Screen.width * 0.22)
    implicitHeight: _col.implicitHeight

    ColumnLayout {
        id: _col
        width: parent.width

        Rectangle {
            Layout.fillWidth: true
            implicitHeight:   _img.height
            color:            Style.surfaceLowColor
            radius:           Style.panelElementRadius
            clip:             true
            border.width:     Style.borderWidth
            border.color:     Style.borderFaintColor

            Image {
                id: _img
                width:  parent.width
                height: sourceSize.width > 0
                    ? Math.round(width * sourceSize.height / sourceSize.width)
                    : width
                source:   root.imagePath !== "" ? ("file://" + root.imagePath) : ""
                fillMode: Image.PreserveAspectFit
            }
        }
    }
}
