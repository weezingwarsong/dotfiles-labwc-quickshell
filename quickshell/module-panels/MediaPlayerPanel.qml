import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property var mprisProcess: null
    signal navigateRequested(int direction)

    readonly property var  _player:      mprisProcess ? mprisProcess.activePlayer : null
    property real          _savedVolume: 1.0
    readonly property bool _muted:       !!_player && _player.volume < 0.01

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
            id:               _artContainer
            Layout.fillWidth: true
            implicitHeight:   width
            visible:          !!root._player

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

                MouseArea {
                    anchors.fill: parent
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        if (!root._player) return
                        var entry = root._player.desktopEntry || ""
                        if (!entry) return
                        _focusProc._appId = entry
                        _focusProc.running = true
                    }
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

            // Marquee track info — click to play/pause
            Item {
                id:               _marqueeClip
                Layout.fillWidth: true
                height:           Style.buttonHeight
                clip:             true

                Text {
                    id:             _marqueeText
                    y:              Math.round((_marqueeClip.height - height) / 2)
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
        }

        // ── Volume ────────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            height:           Style.buttonHeight
            visible:          !!root._player

            WheelHandler {
                onWheel: (event) => {
                    if (!root._player) return
                    var delta  = event.angleDelta.y > 0 ? 0.05 : -0.05
                    var newVol = Math.max(0.0, Math.min(1.0, root._player.volume + delta))
                    if (newVol > 0) root._savedVolume = newVol
                    root._player.volume = newVol
                }
            }

            Rectangle {
                anchors.fill: parent
                radius:       Style.radSm
                color:        Style.surfaceMidColor

                Text {
                    anchors.centerIn: parent
                    text:  root._muted
                           ? "M"
                           : Math.round((root._player ? root._player.volume : 0) * 100) + "%"
                    color: root._muted ? Style.textMuted : Style.textSecondary
                    font.family:    Style.fontMono
                    font.pixelSize: Style.fontSizeBody
                }

                MouseArea {
                    anchors.fill: parent
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
    }

    // Focus the player's window when album art is clicked
    Process {
        id: _focusProc
        property string _appId: ""
        command: ["wlrctl", "toplevel", "focus", "app_id:" + _appId]
        running: false
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
