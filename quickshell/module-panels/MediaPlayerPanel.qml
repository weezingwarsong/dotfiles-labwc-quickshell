import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Io

Item {
    id: root

    property var mprisProcess:    null
    property var toplevelProcess: null

    Keys.onPressed: (event) => {
        if (!root._player) { event.accepted = false; return }
        switch (event.key) {
        case Qt.Key_P:
            if (root._player.canTogglePlaying) root._player.togglePlaying()
            event.accepted = true; break
        case Qt.Key_N:
            if (root._player.canGoNext) root._player.next()
            event.accepted = true; break
        case Qt.Key_B:
            if (root._player.canGoPrevious) root._player.previous()
            event.accepted = true; break
        case Qt.Key_M:
            root._focusPlayer()
            event.accepted = true; break
        case Qt.Key_Up:
            root._player.volume = Math.min(1.0, root._player.volume + 0.05)
            if (root._player.volume > 0) root._savedVolume = root._player.volume
            event.accepted = true; break
        case Qt.Key_Down:
            root._player.volume = Math.max(0.0, root._player.volume - 0.05)
            if (root._player.volume > 0) root._savedVolume = root._player.volume
            event.accepted = true; break
        default:
            event.accepted = false
        }
    }

    readonly property var  _player:      mprisProcess ? mprisProcess.activePlayer : null
    property real          _savedVolume: 1.0
    readonly property bool _muted:       !!_player && _player.volume < 0.01

    implicitHeight: _col.implicitHeight

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 8

        // ── No active player ──────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible:          !root._player
            spacing:          6

            Text {
                Layout.fillWidth:    true
                text:                "No active player"
                color:               Style.textMuted
                font.family:         Style.fontMono
                font.pixelSize:      Style.fontSizeBody
                topPadding:          16
                bottomPadding:       8
            }

            IconButton {
                label:     String.fromCodePoint(0xf001)
                onClicked: _openMusicProc.running = true
            }
        }

        // ── Album art ─────────────────────────────────────────────────────────
        Item {
            Layout.preferredWidth:  _col.width * 0.9
            Layout.preferredHeight: _col.width * 0.9
            Layout.alignment:       Qt.AlignHCenter
            visible:                !!root._player

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler   { onTapped: root._focusPlayer() }

            Rectangle {
                anchors.fill: parent
                radius:       Style.panelElementRadius
                color:        Style.surfaceLowColor
                clip:         true

                Image {
                    id:           _artImage
                    anchors.fill: parent
                    source:       root._player && root._player.trackArtUrl
                                  ? root._player.trackArtUrl : ""
                    fillMode:     Image.PreserveAspectCrop
                    visible:      status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible:          !_artImage.visible
                    text:             String.fromCodePoint(0xf001)
                    color:            Style.textFaint
                    font.family:      Style.fontNerd
                    font.pixelSize:   Math.round(_col.width * 0.9 * 0.35)
                }
            }
        }

        // ── Controls ──────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing:          4
            visible:          !!root._player

            IconButton {
                label:    String.fromCodePoint(0xf048)
                opacity:  root._player && root._player.canGoPrevious ? 1.0 : 0.35
                enabled:  !!root._player && root._player.canGoPrevious
                onClicked: root._player.previous()
            }

            // Marquee track info — hover to reveal play/pause, click to toggle
            Item {
                id:               _marqueeClip
                Layout.fillWidth: true
                implicitHeight:   Style.buttonHeight
                clip:             true

                HoverHandler {
                    id: _marqueeHover
                    onHoveredChanged: if (!hovered) {
                        _scrollAnim.stop()
                        _marqueeText.x = 0
                        Qt.callLater(function() {
                            if (_marqueeText.implicitWidth > _marqueeClip.width)
                                _scrollAnim.start()
                        })
                    }
                }

                Text {
                    id:             _marqueeText
                    y:              Math.round((_marqueeClip.height - height) / 2)
                    visible:        !_marqueeHover.hovered
                    color:          Style.textNormal
                    font.family:    Style.fontMono
                    font.pixelSize: Style.fontSizeBody

                    text: {
                        if (!root._player) return ""
                        var a = root._player.trackArtist || ""
                        var t = root._player.trackTitle  || ""
                        return a ? (a + " — " + t) : t
                    }

                    onTextChanged: {
                        _scrollAnim.stop()
                        x = 0
                        Qt.callLater(function() {
                            if (_marqueeText.implicitWidth > _marqueeClip.width)
                                _scrollAnim.start()
                        })
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible:          _marqueeHover.hovered && !!root._player
                    text: {
                        if (!root._player) return ""
                        return root._player.playbackState === MprisPlaybackState.Playing
                               ? String.fromCodePoint(0xf04b)
                               : String.fromCodePoint(0xf04c)
                    }
                    color:          Style.textNormal
                    font.family:    Style.fontNerd
                    font.pixelSize: Style.fontSizeHeading
                }

                MouseArea {
                    anchors.fill: parent
                    enabled:      !!root._player && root._player.canTogglePlaying
                    cursorShape:  enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked:    root._player.togglePlaying()
                }
            }

            IconButton {
                label:    String.fromCodePoint(0xf051)
                opacity:  root._player && root._player.canGoNext ? 1.0 : 0.35
                enabled:  !!root._player && root._player.canGoNext
                onClicked: root._player.next()
            }

            // ── Volume button ─────────────────────────────────────────────────
            ScrollChip {
                Layout.preferredWidth: 70
                variant:         "bar"
                value:           root._player ? root._player.volume : 0
                muted:           root._muted
                glyph:           root._muted
                                 ? String.fromCodePoint(0xf026)
                                 : String.fromCodePoint(0xf028)
                glyphFontFamily: Style.fontNerd
                label:           ""
                onScrolled: (d) => {
                    if (!root._player) return
                    var newVol = Math.max(0.0, Math.min(1.0, root._player.volume + d * 0.05))
                    if (newVol > 0) root._savedVolume = newVol
                    root._player.volume = newVol
                }
                onClicked: {
                    if (!root._player) return
                    if (root._muted) {
                        root._player.volume = root._savedVolume > 0 ? root._savedVolume : 1.0
                    } else {
                        root._savedVolume   = root._player.volume
                        root._player.volume = 0.0
                    }
                }
            }
        }
    }

    Process {
        id:      _openMusicProc
        command: ["xdg-open", "https://music.youtube.com/watch?list=PLvjbqrIsCjSRP3ZQAuQK93XSfmpwJkSqT&playnext=1&autoplay=1"]
    }

    SequentialAnimation {
        id:    _scrollAnim
        loops: Animation.Infinite

        PauseAnimation  { duration: 1500 }
        NumberAnimation {
            target:      _marqueeText
            property:    "x"
            to:          -(_marqueeText.implicitWidth - _marqueeClip.width)
            duration:    Math.max(1, _marqueeText.implicitWidth - _marqueeClip.width) * 15
            easing.type: Easing.Linear
        }
        PauseAnimation  { duration: 1500 }
        NumberAnimation {
            target:      _marqueeText
            property:    "x"
            to:          0
            duration:    400
            easing.type: Easing.InOutQuad
        }
    }

    function _focusPlayer() {
        if (!root._player || !root.toplevelProcess) return
        var entry    = (root._player.desktopEntry || "").toLowerCase()
        var identity = (root._player.identity     || "").toLowerCase()
        var guess    = identity.replace(/\s+/g, "-")
        var wins     = root.toplevelProcess.windows.values
        for (var i = 0; i < wins.length; i++) {
            var id = wins[i].appId.toLowerCase()
            if ((entry && id === entry) || id === guess) {
                wins[i].activate()
                return
            }
        }
    }
}
