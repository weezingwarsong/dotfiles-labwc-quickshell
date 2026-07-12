import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root

    // Injected by shell.qml
    property var mprisProcess: null

    // ── Priority interface (read by PillController) ───────────────────────────

    readonly property bool _playing: mprisProcess !== null
        && mprisProcess.activePlayer !== null
        && mprisProcess.activePlayer.trackTitle !== ""
        && mprisProcess.activePlayer.playbackState === MprisPlaybackState.Playing

    property bool _peeking: false

    readonly property int  priority:     _playing ? 5 : 0
    readonly property bool shouldReveal: _peeking

    Connections {
        target: mprisProcess
        function onPlayerUpdated(player) {
            root._peeking = true
            _hideTimer.restart()
        }
    }

    Timer {
        id: _hideTimer
        interval: 3000
        onTriggered: root._peeking = false
    }

    // ── Visual component ──────────────────────────────────────────────────────

    property Component visualComponent: Component {
        Row {
            height: parent.height
            spacing: 6

            Text {
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: {
                    if (!root.mprisProcess || !root.mprisProcess.activePlayer) return ""
                    var s = root.mprisProcess.activePlayer.playbackState
                    if (s === MprisPlaybackState.Playing) return String.fromCodePoint(0xf04b)  // nf-fa-play
                    if (s === MprisPlaybackState.Paused)  return String.fromCodePoint(0xf04c)  // nf-fa-pause
                    return String.fromCodePoint(0xf04d)                                        // nf-fa-stop
                }
                color: Style.accentColor
                font.family: Style.fontNerd
                font.pixelSize: Style.fontSizePill
            }

            ScrollingText {
                height: parent.height
                width: implicitWidth
                text: {
                    if (!root.mprisProcess || !root.mprisProcess.activePlayer) return ""
                    var p = root.mprisProcess.activePlayer
                    var a = p.trackArtist || ""
                    var t = p.trackTitle  || ""
                    if (a && t) return a + " — " + t
                    return t || a
                }
                color: Style.textPrimary
                font.family: Style.fontMono
                font.pixelSize: Style.fontSizePill
                maxWidth: 200
            }
        }
    }

    // ── Logging ───────────────────────────────────────────────────────────────
    onPriorityChanged:     console.log("[MprisPill] priority:", priority, "| playing:", _playing)
    onShouldRevealChanged: console.log("[MprisPill] shouldReveal:", shouldReveal,
        "| track:", mprisProcess && mprisProcess.activePlayer
            ? mprisProcess.activePlayer.trackTitle : "none")

    Component.onCompleted: console.log("[MprisPill] started")
}
