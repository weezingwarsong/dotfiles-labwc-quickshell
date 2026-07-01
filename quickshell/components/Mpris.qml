import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Quickshell.Services.Mpris

// Panel-only: the pill row itself lives in MprisPill.qml, rolled by the
// shared bar in shell.qml.  This component is just the expanded player
// panel, anchored directly below the bar. `hovered` and `pinned` are fed in
// externally from shell.qml's root-level combined-region hover/pin state
// (not local to this instance, since it gets destroyed/recreated whenever
// another module briefly takes over the bar).
Item {
    id: root
    property MprisPlayer player: null
    property bool hovered: false
    property bool pinned: false

    signal dismissRequested()

    readonly property int    _gap:       Math.round(Screen.height * 0.01)
    readonly property string _focusAppId: {
        if (!root.player) return ""
        if (root.player.desktopEntry) return root.player.desktopEntry
        return root.player.identity.toLowerCase().replace(/ /g, '-')
    }
    readonly property string _iconPlay:  String.fromCharCode(0xf04b)
    readonly property string _iconPause: String.fromCharCode(0xf04c)
    readonly property string _iconPrev:  String.fromCharCode(0xf048)
    readonly property string _iconNext:  String.fromCharCode(0xf051)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: (hovered || pinned) ? _gap + playerPanel.implicitHeight : 0

    // ── Expanded player panel (rectangle-normal) ─────────────────────────────
    Rectangle {
        id: playerPanel
        anchors.top: parent.top
        anchors.topMargin: root._gap
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        color: Style.panelBg
        border.width: Style.borderWidth
        border.color: Style.panelBorder
        implicitHeight: col.implicitHeight + 16

        Column {
            id: col
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 8
                leftMargin: 8
                rightMargin: 8
            }
            spacing: 8

            // Always reserved so pinning doesn't resize the panel — only the
            // button's own visibility toggles within this constant-height row.
            Item {
                width: parent.width
                height: 22

                PinButton {
                    visible: root.pinned
                    onClicked: root.dismissRequested()
                }
            }

            // Album art
            Rectangle {
                width: parent.width
                height: parent.width
                color: Style.textPanelLow

                Image {
                    anchors.fill: parent
                    source: root.player ? (root.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }

            // Title
            Text {
                width: parent.width
                text: root.player ? (root.player.trackTitle || "") : ""
                color: Style.textBright
                font.family: Style.fontFamily
                font.pointSize: Style.fontSize
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // Artist
            Text {
                width: parent.width
                text: root.player ? (root.player.trackArtist || "") : ""
                color: Style.textPanelHighlight
                font.family: Style.fontFamily
                font.pointSize: Style.fontSize
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // Controls: prev / play-pause / next
            Item {
                width: parent.width
                height: Style.pillHeight

                Row {
                    anchors.centerIn: parent
                    spacing: 20

                    Text {
                        text: root._iconPrev
                        color: root.player && root.player.canGoPrevious ? Style.textPanelNormal : Style.textPanelLow
                        font.family: Style.fontFamily
                        font.pointSize: 14
                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
                        }
                    }

                    Text {
                        text: root.player && root.player.playbackState === MprisPlaybackState.Playing ? root._iconPause : root._iconPlay
                        color: Style.textPanelNormal
                        font.family: Style.fontFamily
                        font.pointSize: 14
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (!root.player) return
                                if (root.player.playbackState === MprisPlaybackState.Playing)
                                    root.player.pause()
                                else
                                    root.player.play()
                            }
                        }
                    }

                    Text {
                        text: root._iconNext
                        color: root.player && root.player.canGoNext ? Style.textPanelNormal : Style.textPanelLow
                        font.family: Style.fontFamily
                        font.pointSize: 14
                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (root.player && root.player.canGoNext) root.player.next()
                        }
                    }
                }
            }

            // Focus source window — wrapper keeps Column layout stable during hover expansion
            Item {
                width: parent.width
                height: Style.pillHeight
            Rectangle {
                id: focusBtn
                property bool localHovered: false
                x: localHovered ? -2 : 0
                y: localHovered ? -2 : 0
                width: localHovered ? parent.width + 4 : parent.width
                height: localHovered ? 28 : Style.pillHeight
                color: Style.panelButtonBg
                border.width: Style.borderWidth
                border.color: Style.panelButtonBorder
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Style.nord0
                    shadowBlur: focusBtn.localHovered ? 0.55 : 0.25
                    shadowVerticalOffset: focusBtn.localHovered ? 6 : 2
                    shadowOpacity: focusBtn.localHovered ? 0.8 : 0.5
                }

                HoverHandler { onHoveredChanged: focusBtn.localHovered = hovered }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root._focusAppId) focusProcess.running = true
                }

                Text {
                    id: focusIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCharCode(0xf2d0)
                    color: Style.textPanelHighlight
                    font.family: Style.fontFamily
                    font.pointSize: Style.fontSize
                }

                Text {
                    anchors.left: focusIcon.right
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player ? (root.player.identity || root.player.desktopEntry || "") : ""
                    color: Style.textPanelHighlight
                    font.family: Style.fontFamily
                    font.pointSize: Style.fontSize
                    elide: Text.ElideRight
                }

                Process {
                    id: focusProcess
                    command: ["wlrctl", "toplevel", "focus", "app_id:" + root._focusAppId]
                }
            }
            } // Item wrapper
        }
    }
}
