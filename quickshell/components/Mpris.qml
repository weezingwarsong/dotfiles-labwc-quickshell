import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root
    property MprisPlayer player: null
    property bool hovered: false

    signal wantsDismiss()

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
    implicitHeight: hovered ? 24 + _gap + playerPanel.implicitHeight : 24

    HoverHandler {
        onHoveredChanged: {
            root.hovered = hovered
            if (!hovered && (!root.player || root.player.playbackState !== MprisPlaybackState.Playing))
                root.wantsDismiss()
        }
    }

    // ── Pill (rectangle-main) ────────────────────────────────────────────────
    Rectangle {
        id: pill
        property bool localHovered: false
        x: localHovered ? -2 : 0
        width: localHovered ? parent.width + 4 : parent.width
        height: localHovered ? 26 : 24
        color: Style.rectMainBg
        border.width: Style.rectBorderWidth
        border.color: Style.rectMainBorder
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#2E3440"
            shadowBlur: pill.localHovered ? 0.55 : 0.25
            shadowVerticalOffset: pill.localHovered ? 6 : 2
            shadowOpacity: pill.localHovered ? 0.8 : 0.5
            Behavior on shadowBlur { NumberAnimation { duration: 120 } }
            Behavior on shadowVerticalOffset { NumberAnimation { duration: 120 } }
            Behavior on shadowOpacity { NumberAnimation { duration: 120 } }
        }
        Behavior on x { NumberAnimation { duration: 80 } }
        Behavior on width { NumberAnimation { duration: 80 } }
        Behavior on height { NumberAnimation { duration: 80 } }

        HoverHandler { onHoveredChanged: pill.localHovered = hovered }

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

        Text {
            id: pillIcon
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.player && root.player.playbackState === MprisPlaybackState.Playing ? root._iconPause : root._iconPlay
            color: Style.textHeaderHighlight
            font.family: Style.fontFamily
            font.pointSize: Style.fontSize
        }

        Text {
            anchors.left: pillIcon.right
            anchors.leftMargin: 6
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (!root.player) return ""
                var artist = root.player.trackArtist || ""
                var title  = root.player.trackTitle  || ""
                return artist ? artist + " – " + title : title
            }
            color: Style.textHeaderNormal
            font.family: Style.fontFamily
            font.pointSize: Style.fontSize
            elide: Text.ElideRight
        }
    }

    // ── Expanded player panel (rectangle-normal) ─────────────────────────────
    Rectangle {
        id: playerPanel
        anchors.top: pill.bottom
        anchors.topMargin: root._gap
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        color: Style.rectNormalBg
        border.width: Style.rectBorderWidth
        border.color: Style.rectNormalBorder
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

            // Album art
            Rectangle {
                width: parent.width
                height: parent.width
                color: Style.textBodyLow

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
                color: Style.textBodyHighlight
                font.family: Style.fontFamily
                font.pointSize: Style.fontSize
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // Controls: prev / play-pause / next
            Item {
                width: parent.width
                height: 24

                Row {
                    anchors.centerIn: parent
                    spacing: 20

                    Text {
                        text: root._iconPrev
                        color: root.player && root.player.canGoPrevious ? Style.textBodyNormal : Style.textBodyLow
                        font.family: Style.fontFamily
                        font.pointSize: 14
                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
                        }
                    }

                    Text {
                        text: root.player && root.player.playbackState === MprisPlaybackState.Playing ? root._iconPause : root._iconPlay
                        color: Style.textBodyNormal
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
                        color: root.player && root.player.canGoNext ? Style.textBodyNormal : Style.textBodyLow
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
                height: 24
            Rectangle {
                id: focusBtn
                property bool localHovered: false
                x: localHovered ? -2 : 0
                y: localHovered ? -2 : 0
                width: localHovered ? parent.width + 4 : parent.width
                height: localHovered ? 28 : 24
                color: Style.rectButtonBg
                border.width: Style.rectBorderWidth
                border.color: Style.rectButtonBorder
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#2E3440"
                    shadowBlur: focusBtn.localHovered ? 0.55 : 0.25
                    shadowVerticalOffset: focusBtn.localHovered ? 6 : 2
                    shadowOpacity: focusBtn.localHovered ? 0.8 : 0.5
                    Behavior on shadowBlur { NumberAnimation { duration: 120 } }
                    Behavior on shadowVerticalOffset { NumberAnimation { duration: 120 } }
                    Behavior on shadowOpacity { NumberAnimation { duration: 120 } }
                }
                Behavior on x { NumberAnimation { duration: 80 } }
                Behavior on y { NumberAnimation { duration: 80 } }
                Behavior on width { NumberAnimation { duration: 80 } }
                Behavior on height { NumberAnimation { duration: 80 } }

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
                    color: Style.textBodyHighlight
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
                    color: Style.textBodyHighlight
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
