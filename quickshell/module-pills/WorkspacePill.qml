import QtQuick
import Quickshell

Item {
    id: root

    // Injected by shell.qml
    property var workspaceProcess: null

    // ── Reveal condition ──────────────────────────────────────────────────────
    property bool shouldShow: false

    Connections {
        target: workspaceProcess
        function onWorkspaceChanged() {
            root.shouldShow = true
            _hideTimer.restart()
        }
    }

    Timer {
        id: _hideTimer
        interval: 1500
        onTriggered: root.shouldShow = false
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
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.displayText
                color: Style.textPrimary
                font.pixelSize: Style.pillTextSize
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
                            ? String.fromCodePoint(0xF0445)
                            : String.fromCodePoint(0xF0444)
                        color: Style.textPrimary
                        font.family: Style.fontNerd
                        font.pixelSize: Style.pillTextSize
                    }
                }
            }
        }
    }

    // ── Logging ───────────────────────────────────────────────────────────────
    onShouldShowChanged: console.log("[WorkspacePill] shouldShow:", shouldShow,
        "| workspace:", displayText)

    Component.onCompleted: console.log("[WorkspacePill] started")
}
