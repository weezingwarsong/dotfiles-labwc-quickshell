import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property var screenrecProcess: null
    readonly property bool shouldShow: _showingSaved

    property bool   _showingSaved: false
    property string _savedPath:    ""
    property int    _elapsedSecs:  0   // tracks duration while recording, for display in saved state
    property int    _savedSecs:    0

    visible:        shouldShow
    implicitHeight: shouldShow ? _card.implicitHeight : 0

    Connections {
        target: root.screenrecProcess
        function onRecordingStarted() {
            root._elapsedSecs = 0
            _elapsed.start()
        }
        function onRecordingStopped(path) {
            root._savedSecs    = root._elapsedSecs
            root._savedPath    = path
            root._showingSaved = true
            _elapsed.stop()
            _dismissTimer.start(Prefs.notificationTimeout)
        }
        function onRecordingError() { _elapsed.stop() }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                if (_dismissTimer.running) _dismissTimer.pause()
            } else {
                if (_dismissTimer.running) _dismissTimer.resume()
            }
        }
    }

    Timer {
        id: _elapsed
        interval: 1000; repeat: true
        onTriggered: root._elapsedSecs++
    }

    function _dismiss() {
        _dismissTimer.kill()
        root._showingSaved = false
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root._dismiss()
    }

    PanelCard {
        id: _card
        anchors.fill: parent
        color: Style.surfaceLowColor

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root._showingSaved

            Text {
                text:           root._savedPath.split("/").pop()
                color:          Style.textNormal
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeSubtle
                elide:          Text.ElideMiddle
                Layout.fillWidth: true
            }

            Text {
                text:           _fmt(root._savedSecs)
                color:          Style.textMuted
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeSubtle
            }

            // open file
            IconButton {
                label: "▶"
                onClicked: if (root._savedPath !== "") _openProc.running = true
            }

            // copy path
            IconButton {
                label: "⋮"
                onClicked: { _copyPathProc.running = true; root._showingSaved = false }
            }
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

    LocalTimer {
        id: _dismissTimer
        variant: 4
        color:   Style.accentColor
        Layout.fillWidth: true
        visible: running && root._showingSaved
        onCompleted: root._dismiss()
    }

    Process { id: _openProc;     command: ["xdg-open", root._savedPath] }
    Process { id: _copyPathProc; command: ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", root._savedPath] }
}
