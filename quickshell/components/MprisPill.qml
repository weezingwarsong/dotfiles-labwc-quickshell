import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root
    property MprisPlayer player: null
    property bool hovered: false

    signal wantsDismiss()

    readonly property string _iconPlay:  String.fromCharCode(0xf04b)
    readonly property string _iconPause: String.fromCharCode(0xf04c)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Style.pillHeight

    HoverHandler {
        onHoveredChanged: {
            root.hovered = hovered
            if (!hovered && (!root.player || root.player.playbackState !== MprisPlaybackState.Playing))
                root.wantsDismiss()
        }
    }

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
        color: Style.textPillHighlight
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
        color: Style.textPillNormal
        font.family: Style.fontFamily
        font.pointSize: Style.fontSize
        elide: Text.ElideRight
    }
}
