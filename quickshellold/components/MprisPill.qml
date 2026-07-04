import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root
    property MprisPlayer player: null
    property bool hovered: false  // unused; present so every Pill shares the same interface

    readonly property string _iconPlay:  String.fromCharCode(0xf04b)
    readonly property string _iconPause: String.fromCharCode(0xf04c)

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Style.pillHeight

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

    // Marquee: one-way continuous scroll-left-and-snap-back, unlike the
    // player panel's back-and-forth version — this is a much smaller,
    // always-glanceable area, so a simple continuous loop reads better
    // than a pause/bounce cycle.
    Item {
        id: titleClip
        anchors.left: pillIcon.right
        anchors.leftMargin: 6
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: pillText.implicitHeight
        clip: true

        readonly property real overflowPx: Math.max(0, pillText.implicitWidth - titleClip.width)

        Text {
            id: pillText
            text: {
                if (!root.player) return ""
                var artist = root.player.trackArtist || ""
                var title  = root.player.trackTitle  || ""
                return artist ? artist + " – " + title : title
            }
            color: Style.textPillNormal
            font.family: Style.fontFamily
            font.pointSize: Style.fontSize
            width: titleClip.overflowPx > 0 ? implicitWidth : titleClip.width

            NumberAnimation on x {
                running: titleClip.overflowPx > 0
                loops: Animation.Infinite
                from: 0
                to: -titleClip.overflowPx
                duration: Math.max(2000, titleClip.overflowPx * 40)
                onRunningChanged: if (!running) pillText.x = 0
            }
        }
    }
}
