import Quickshell
import Quickshell.Wayland
import QtQuick
import QtMultimedia

PanelWindow {
    id: root
    property url source: ""

    readonly property bool sourceIsVideo: {
        var s = source.toString()
        if (s === "") return false
        var ext = s.split('.').pop().toLowerCase()
        return ["webm", "mp4", "mkv", "avi", "mov"].indexOf(ext) !== -1
    }

    WlrLayershell.layer: WlrLayer.Background
    exclusiveZone: -1
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "#2E3440"
    mask: Region {}

    AnimatedImage {
        anchors.fill: parent
        visible: !root.sourceIsVideo
        source: root.source
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        visible: root.sourceIsVideo
    }

    MediaPlayer {
        id: player
        videoOutput: videoOutput
        source: root.sourceIsVideo ? root.source : ""
        loops: MediaPlayer.Infinite
        onSourceChanged: if (root.sourceIsVideo && source != "") play()
    }
}
