import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Item {
    id: root

    property var    mprisProcess:    null
    property var    toplevelProcess: null
    property string activePanel:     ""
    signal navigateRequested(int direction)

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

    readonly property var  _player:      mprisProcess ? mprisProcess.activePlayer : null
    property real          _savedVolume: 1.0
    readonly property bool _muted:       !!_player && _player.volume < 0.01
    readonly property real _artSize:     width - 2 * Style.panelMargin

    implicitHeight: _col.implicitHeight + 24

    Rectangle {
        anchors.fill:  parent
        radius:        Style.radLg
        color:         Style.panelBgColor
        border.color:  Style.panelBorderColor
        border.width:  1
        clip:          true
    }

    ColumnLayout {
        id: _col
        anchors {
            top:     parent.top
            left:    parent.left
            right:   parent.right
            margins: Style.panelMargin
        }
        spacing: 8

        // ── Nav bar ───────────────────────────────────────────────────────────
        PanelNavBar {
            Layout.fillWidth: true
            activePanel: root.activePanel
            onNavigateRequested: (dir) => root.navigateRequested(dir)
        }

        // ── No active player ──────────────────────────────────────────────────
        Text {
            Layout.fillWidth:    true
            visible:             !root._player
            text:                "No active player"
            color:               Style.textMuted
            font.family:         Style.fontMono
            font.pixelSize:      Style.fontSizeBody
            horizontalAlignment: Text.AlignHCenter
            topPadding:          16
            bottomPadding:       8
        }

        // ── Album art ─────────────────────────────────────────────────────────
        Item {
            id:                      _artContainer
            Layout.fillWidth:        true
            Layout.preferredHeight:  root._artSize
            visible:                 !!root._player

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler   { onTapped: root._focusPlayer() }

            Rectangle {
                anchors.fill: parent
                radius:       Style.radMd
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
                    font.pixelSize:   Math.round(_artContainer.width * 0.35)
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
                height:           Style.buttonHeight
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

                // Track text — hidden while hovered
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

                // Play/pause glyph — shown while hovered
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
            Item {
                id:     _volBtn
                width:  40
                height: Style.buttonHeight

                HoverHandler { id: _volHover }

                // Glyph (not hovered)
                Text {
                    anchors.centerIn: parent
                    visible:          !_volHover.hovered
                    text:             root._muted
                                      ? String.fromCodePoint(0xf026)   // nf-fa-volume-off
                                      : String.fromCodePoint(0xf028)   // nf-fa-volume-up
                    color:            root._muted ? Style.textMuted : Style.accentColor
                    font.family:      Style.fontNerd
                    font.pixelSize:   Style.fontSizeBody
                }

                // Volume bar (hovered)
                Item {
                    anchors.centerIn: parent
                    width:            parent.width - 8
                    height:           4
                    visible:          _volHover.hovered

                    Rectangle {
                        anchors.fill: parent
                        radius:       2
                        color:        Style.surfaceMidColor
                    }
                    Rectangle {
                        width:  parent.width * Math.max(0, Math.min(1, root._player ? root._player.volume : 0))
                        height: parent.height
                        radius: 2
                        color:  root._muted ? Style.textMuted : Style.accentColor
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        if (!root._player) return
                        if (root._muted) {
                            root._player.volume = root._savedVolume > 0 ? root._savedVolume : 1.0
                        } else {
                            root._savedVolume   = root._player.volume
                            root._player.volume = 0.0
                        }
                    }
                    onWheel: (wheel) => {
                        if (!root._player) return
                        var delta  = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                        var newVol = Math.max(0.0, Math.min(1.0, root._player.volume + delta))
                        if (newVol > 0) root._savedVolume = newVol
                        root._player.volume = newVol
                    }
                }
            }
        }
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
}
