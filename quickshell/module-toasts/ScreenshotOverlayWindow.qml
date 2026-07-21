import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool   active:    false
    property string imagePath: ""
    property string filename:  ""

    screen:         Quickshell.screens[0]
    anchors.right:  true
    anchors.bottom: true

    // Sits to the left of ToastWindow, same bottom margin
    WlrLayershell.margins {
        right:  Math.round(Screen.width * 0.15) + Math.round(Screen.height * 0.02) + 8
        bottom: Math.round(Screen.height * 0.02)
    }
    WlrLayershell.layer: WlrLayer.Overlay

    exclusiveZone: 0
    color:         "transparent"
    visible:       root.active && root.imagePath !== ""

    // Fully passthrough — mouse events fall through to toast beneath
    mask: Region { }

    implicitWidth:  Math.round(Screen.width * 0.25)
    implicitHeight: _col.implicitHeight

    ColumnLayout {
        id: _col
        width: parent.width
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            implicitHeight:   _label.implicitHeight + 12
            color:            Style.surfaceMidColor
            radius:           Style.panelElementRadius
            border.width:     Style.borderWidth
            border.color:     Style.borderFaintColor

            Text {
                id: _label
                anchors {
                    left: parent.left;   leftMargin:  12
                    right: parent.right; rightMargin: 12
                    verticalCenter: parent.verticalCenter
                }
                text:                root.filename !== "" ? root.filename + " — copied!" : "Copied!"
                color:               Style.accentColor
                font.family:         Style.fontMono
                font.pixelSize:      Style.fontSizeBody
                elide:               Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }
        }

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
                source:   root.imagePath
                fillMode: Image.PreserveAspectFit
            }
        }
    }
}
