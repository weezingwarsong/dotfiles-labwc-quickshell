import QtQuick
import Quickshell

Item {
    id: root

    // Injected by shell.qml
    property var workspaceProcess: null

    // ── Priority interface (read by PillController) ───────────────────────────

    property bool _active: false

    readonly property int  priority:     _active ? 100 : 0
    readonly property bool shouldReveal: _active

    Connections {
        target: workspaceProcess
        function onWorkspaceChanged() {
            root._active = true
            _hideTimer.restart()
        }
    }

    Timer {
        id: _hideTimer
        interval: 1500
        onTriggered: root._active = false
    }

    // ── Display text ──────────────────────────────────────────────────────────
    readonly property string displayText: {
        if (workspaceProcess && workspaceProcess.current)
            return workspaceProcess.current.name
        return ""
    }

    // ── Visual component ──────────────────────────────────────────────────────
    property Component visualComponent: Component {
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.displayText
                color: Style.textPrimary
                font.pixelSize: Style.fontSizePill
                font.family: Style.fontMono
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: root.workspaceProcess ? root.workspaceProcess.list.length : 0
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: index === (root.workspaceProcess ? root.workspaceProcess.currentIndex : -1)
                            ? String.fromCodePoint(0xf444)
                            : String.fromCodePoint(0xf4c3)
                        color: Style.textPrimary
                        font.family: Style.fontNerd
                        font.pixelSize: Style.fontSizePill
                    }
                }
            }
        }
    }

    // ── Logging ───────────────────────────────────────────────────────────────
    onShouldRevealChanged: console.log("[WorkspacePill] shouldReveal:", shouldReveal,
        "| workspace:", displayText)

    Component.onCompleted: console.log("[WorkspacePill] started")
}
