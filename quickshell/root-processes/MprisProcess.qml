import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root

    // ── Outputs ───────────────────────────────────────────────────────────────
    readonly property var players: Mpris.players   // ObjectModel<MprisPlayer>
    property var activePlayer: null                // Playing > Paused > first available

    signal playerUpdated(var player)   // track change OR playback state change

    // ── Player selection ──────────────────────────────────────────────────────
    // Called whenever a player is added, removed, or changes state. Prefers a
    // Playing player over Paused over any available, so pausing one app while
    // another is playing doesn't clobber the display.
    function _selectPlayer() {
        var vals = Mpris.players.values
        if (!vals || vals.length === 0) { root.activePlayer = null; return }
        var playing = null
        var paused  = null
        for (var i = 0; i < vals.length; i++) {
            var p = vals[i]
            if (p.playbackState === MprisPlaybackState.Playing && !playing) playing = p
            else if (p.playbackState === MprisPlaybackState.Paused && !paused) paused = p
        }
        root.activePlayer = playing || paused || vals[0]
    }

    // ── Watch each player for state/track changes ─────────────────────────────
    Instantiator {
        model: Mpris.players
        delegate: QtObject {
            required property var modelData
            property var _watch: Connections {
                target: modelData
                function onPlaybackStateChanged() {
                    root._selectPlayer()
                    root.playerUpdated(modelData)
                    console.log("[MprisProcess] playbackState →", modelData.playbackState,
                        "| track:", modelData.trackTitle)
                }
                function onTrackChanged() {
                    root._selectPlayer()
                    root.playerUpdated(modelData)
                    console.log("[MprisProcess] track →", modelData.trackTitle,
                        "by", modelData.trackArtist)
                }
            }
        }
        onObjectAdded:   function(index, object) {
            root._selectPlayer()
            console.log("[MprisProcess] player added:", object.modelData ? object.modelData.trackTitle : "?")
        }
        onObjectRemoved: function(index, object) {
            root._selectPlayer()
            console.log("[MprisProcess] player removed")
        }
    }

    Component.onCompleted: {
        root._selectPlayer()
        var vals = Mpris.players.values
        console.log("[MprisProcess] started. Players:", vals ? vals.length : 0,
            "| Active:", root.activePlayer ? root.activePlayer.trackTitle : "none")
    }
}
