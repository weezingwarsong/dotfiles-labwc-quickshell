import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root

    // Injected by shell.qml
    property var mprisProcess: null

    // ── Stage 1: winner eligibility ──────────────────────────────────────────
    readonly property bool isActive: mprisProcess !== null
        && mprisProcess.activePlayer !== null
        && mprisProcess.activePlayer.trackTitle !== ""

    // ── Stage 2: content-driven peek ─────────────────────────────────────────
    property bool shouldShow: false

    Connections {
        target: mprisProcess
        function onPlayerUpdated(player) {
            root.shouldShow = true
            _hideTimer.restart()
        }
    }

    Timer {
        id: _hideTimer
        interval: 3000
        onTriggered: root.shouldShow = false
    }

    // ── Visual component ──────────────────────────────────────────────────────

    property Component visualComponent: Component {
        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (!root.mprisProcess || !root.mprisProcess.activePlayer) return ""
                    var s = root.mprisProcess.activePlayer.playbackState
                    if (s === MprisPlaybackState.Playing) return String.fromCodePoint(0xf04b)  // nf-fa-play
                    if (s === MprisPlaybackState.Paused)  return String.fromCodePoint(0xf04c)  // nf-fa-pause
                    return String.fromCodePoint(0xf04d)                                        // nf-fa-stop
                }
                color: Style.textPrimary
                font.family: Style.fontNerd
                font.pixelSize: Style.pillTextSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.mprisProcess && root.mprisProcess.activePlayer
                    ? root.mprisProcess.activePlayer.trackTitle
                    : ""
                color: Style.textPrimary
                font.family: Style.fontMono
                font.pixelSize: Style.pillTextSize
                elide: Text.ElideRight
            }
        }
    }

    // ── Logging ───────────────────────────────────────────────────────────────
    onShouldShowChanged: console.log("[MprisPill] shouldShow:", shouldShow,
        "| track:", mprisProcess && mprisProcess.activePlayer
            ? mprisProcess.activePlayer.trackTitle : "none")

    Component.onCompleted: console.log("[MprisPill] started")
}
