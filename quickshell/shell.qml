import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Io
import "components"

ShellRoot {
    id: root

    // "time" | "workspace" | "recording" | "recordingSaved"
    property string activeModule: "time"
    property string currentWorkspace: "1"
    property bool   isRecording: false
    property var    wallpapers: []
    property var    _wallpaperBuf: []

    readonly property url currentWallpaper: {
        var idx = parseInt(currentWorkspace) - 1
        if (idx >= 0 && idx < wallpapers.length)
            return "file://" + wallpapers[idx]
        return ""
    }

    WallpaperWindow {
        source: root.currentWallpaper
    }

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
                source: {
                    if (root.activeModule === "workspace")
                        return Qt.resolvedUrl("components/Workspace.qml")
                    if (root.activeModule === "recording" || root.activeModule === "recordingSaved")
                        return Qt.resolvedUrl("components/RecordingStatus.qml")
                    return Qt.resolvedUrl("components/Time.qml")
                }
                onLoaded: {
                    if (root.activeModule === "workspace")
                        item.workspace = Qt.binding(() => root.currentWorkspace)
                    if (root.activeModule === "recording" || root.activeModule === "recordingSaved")
                        item.saved = Qt.binding(() => root.activeModule === "recordingSaved")
                }
            }
        }
    }

    // Return to time after workspace flash
    Timer {
        id: workspaceTimer
        interval: 1000
        onTriggered: if (root.activeModule === "workspace") root.activeModule = "time"
    }

    // Return to time after "RECORDING SAVED" flash
    Timer {
        id: recordingTimer
        interval: 1000
        onTriggered: root.activeModule = "time"
    }

    // Poll recording state every second
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: if (!recordingCheck.running) recordingCheck.running = true
    }

    Process {
        id: recordingCheck
        command: ["sh", "-c", "test -f /tmp/gsr-pid && kill -0 \"$(cat /tmp/gsr-pid)\" 2>/dev/null"]
        onExited: function(code, signal) {
            var nowRecording = (code === 0)
            if (nowRecording && !root.isRecording) {
                root.isRecording = true
                root.activeModule = "recording"
                workspaceTimer.stop()
                recordingTimer.stop()
            } else if (!nowRecording && root.isRecording) {
                root.isRecording = false
                root.activeModule = "recordingSaved"
                recordingTimer.restart()
            }
        }
    }

    Process {
        id: wallpaperScanner
        command: ["sh", "-c", "find \"$HOME/.config/quickshell/wallpaper\" -maxdepth 1 -type f | sort 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var f = line.trim()
                if (f !== "") root._wallpaperBuf.push(f)
            }
        }
        onExited: function(code, signal) {
            root.wallpapers = root._wallpaperBuf.slice()
        }
    }

    Process {
        id: wsWatcher
        command: ["qs-workspace-watcher"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var ws = line.trim()
                if (ws !== "") {
                    root.currentWorkspace = ws
                    if (!root.isRecording) {
                        root.activeModule = "workspace"
                        workspaceTimer.restart()
                    }
                }
            }
        }
    }
}
