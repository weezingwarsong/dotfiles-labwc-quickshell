import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property var screenshotProcess: null   // unused — kept for interface symmetry
    property var screenrecProcess:  null

    readonly property bool shouldShow: _visible

    property bool   _visible:   false
    property string _path:      ""
    property string _filename:  ""
    property int    _savedSecs: 0

    visible:        _visible
    implicitHeight: _visible ? _card.implicitHeight : 0

    Connections {
        target: root.screenrecProcess
        function onRecordingStopped(path) {
            root._path      = path
            root._filename  = path.split("/").pop()
            root._savedSecs = root._elapsedSecs
            root._visible   = true
            _elapsed.stop()
            _toastTimer.start(Prefs.notificationTimeout)
        }
        function onRecordingStarted() {
            root._elapsedSecs = 0
            _elapsed.start()
        }
        function onRecordingError(reason) { _elapsed.stop() }
    }

    // Tracks elapsed while recording so _savedSecs is available on stop
    property int _elapsedSecs: 0
    Timer {
        id: _elapsed
        interval: 1000; repeat: true
        onTriggered: root._elapsedSecs++
    }

    function _dismiss() {
        _toastTimer.kill()
        root._visible = false
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                if (_toastTimer.running) _toastTimer.pause()
            } else {
                if (_toastTimer.running) _toastTimer.resume()
            }
        }
    }

    TapHandler { acceptedButtons: Qt.RightButton; onTapped: root._dismiss() }

    PanelCard {
        id: _card
        anchors.fill: parent
        color: Style.surfaceMidColor

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MediaThumbnail {
                Layout.fillWidth: true
                source:   root.screenrecProcess && root.screenrecProcess.thumbsReady[root._path]
                          ? root.screenrecProcess.thumbPath(root._path)
                          : ""
                filename: root._filename + (root._savedSecs > 0 ? "  " + root._fmt(root._savedSecs) : "")
                onThumbnailClicked: { if (root._path !== "") _openProc.running = true }
                onFilenameClicked:  { _copyPathProc.running = true; root._dismiss() }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 4

                IconButton { label: "×"; onClicked: root._dismiss() }
                IconButton { label: "▶"; onClicked: if (root._path !== "") _openProc.running = true }
                IconButton { label: "⋮"; enabled: false }
            }
        }

        LocalTimer {
            id: _toastTimer
            variant: 4
            color:   Style.accentColor
            Layout.fillWidth: true
            visible: running
            onCompleted: root._dismiss()
        }
    }

    function _fmt(secs) {
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var s = secs % 60
        if (h > 0) return h + ":" + _p(m) + ":" + _p(s)
        return _p(m) + ":" + _p(s)
    }
    function _p(n) { return n < 10 ? "0" + n : "" + n }

    Process { id: _openProc;     command: ["xdg-open", root._path] }
    Process { id: _copyPathProc; command: ["sh", "-c",
        "printf '%s' \"$1\" | wl-copy", "sh", root._path] }
}
