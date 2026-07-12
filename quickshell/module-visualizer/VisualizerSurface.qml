import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var  clockProcess
    required property var  bars
    property      bool     active:    true
    property      real     skewScale: 0.85  // right-side height as fraction of left (0–1)

    screen:        Quickshell.screens[0]
    exclusiveZone: -1
    WlrLayershell.layer:        WlrLayer.Bottom
    WlrLayershell.margins.left: screen.width * 0.20
    anchors.left: true
    // no top/bottom anchor → compositor centers vertically

    width:  320
    height: 460
    color:  "transparent"
    visible: active

    Item {
        id: content
        anchors.fill: parent

        transform: Matrix4x4 {
            property real s: root.skewScale
            property real w: content.width
            property real h: content.height
            matrix: Qt.matrix4x4(
                1 / s,                      0,  0,  0,
                h * (1 - s) / (2 * s * w), 1,  0,  0,
                0,                          0,  1,  0,
                (1 / s - 1) / w,            0,  0,  1
            )
        }

        Column {
            anchors.fill: parent
            spacing: 16

            // Clock — right-justified
            Column {
                width:   parent.width
                spacing: 4

                Text {
                    width:               parent.width
                    horizontalAlignment: Text.AlignRight
                    text:                root.clockProcess.displayTime
                    font.pixelSize:      Prefs.fontSizeVisClock
                    font.bold:           true
                    font.family:         Prefs.fontVisClock
                    font.letterSpacing:  1.5
                    color: Qt.rgba(Style.accentColor.r, Style.accentColor.g, Style.accentColor.b, 0.75)
                }

                Text {
                    width:               parent.width
                    horizontalAlignment: Text.AlignRight
                    text:                Qt.formatDate(root.clockProcess.now, "d MMM yyyy")
                    font.pixelSize:      Math.max(10, Math.round(Prefs.fontSizeVisClock * 0.24))
                    font.family:         Prefs.fontVisClock
                    font.letterSpacing:  2
                    color: Qt.rgba(Style.accentColor.r, Style.accentColor.g, Style.accentColor.b, 0.45)
                }
            }

            // Radial visualizer — centered
            Item {
                width:  parent.width
                height: 280
                RadialVisualizer {
                    width:  280
                    height: 280
                    anchors.horizontalCenter: parent.horizontalCenter
                    bars: root.bars
                }
            }
        }
    }
}
