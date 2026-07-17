import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property bool hovered: false

    screen: Quickshell.screens[0]
    anchors.top: true
    exclusiveZone: -1
    color: "transparent"

    implicitWidth: Screen.width * 0.10
    implicitHeight: 8

    Item {
        anchors.fill: parent

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    leaveTimer.stop()
                    root.hovered = true
                } else {
                    leaveTimer.restart()
                }
            }
        }
    }

    // Small debounce so jitter at the screen edge doesn't flicker the pill
    Timer {
        id: leaveTimer
        interval: 120
        onTriggered: root.hovered = false
    }
}
