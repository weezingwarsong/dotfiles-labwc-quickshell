import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Io

ShellRoot {
    id: root

    property string activeModule: "time"
    property string currentWorkspace: "1"

    PanelWindow {
        id: panel
        anchors.top: true
        color: "transparent"
        exclusiveZone: 24

        implicitWidth: moduleLoader.implicitWidth
        implicitHeight: moduleLoader.implicitHeight

        Behavior on implicitHeight {
            NumberAnimation {
                duration: 250
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            Loader {
                id: moduleLoader
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                source: root.activeModule === "time"
                    ? Qt.resolvedUrl("modules/Time.qml")
                    : Qt.resolvedUrl("modules/Workspace.qml")
                onLoaded: {
                    if (root.activeModule === "workspace")
                        item.workspace = Qt.binding(() => root.currentWorkspace)
                }
            }
        }
    }

    Timer {
        id: resetTimer
        interval: 1000
        onTriggered: root.activeModule = "time"
    }

    Process {
        id: wsWatcher
        command: ["tail", "-f", "/tmp/qs-workspace"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var ws = line.trim()
                if (ws !== "") {
                    root.currentWorkspace = ws
                    root.activeModule = "workspace"
                    resetTimer.restart()
                }
            }
        }
    }
}
