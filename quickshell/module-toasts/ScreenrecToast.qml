import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property var screenrecProcess: null
    readonly property bool shouldShow: _recording || _showingSaved

    property bool   _recording:    false
    property bool   _showingSaved: false
    property string _savedPath:    ""
    property int    _elapsedSecs:  0
    property int    _savedSecs:    0

    visible:        shouldShow
    implicitHeight: shouldShow ? _card.implicitHeight : 0

    Connections {
        target: root.screenrecProcess
        function onRecordingStarted() {
            root._elapsedSecs = 0
            root._recording   = true
            _elapsed.start()
        }
        function onRecordingStopped(path) {
            root._savedSecs    = root._elapsedSecs
            root._savedPath    = path
            root._recording    = false
            root._showingSaved = true
            _elapsed.stop()
        }
        function onRecordingError() {
            root._recording = false
            _elapsed.stop()
        }
    }

    Timer {
        id: _elapsed
        interval: 1000; repeat: true
        onTriggered: root._elapsedSecs++
    }

    function _dismiss() { if (!root._recording) root._showingSaved = false }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: root._dismiss()
    }

    PanelCard {
        id: _card
        anchors.fill: parent
        color: root._recording ? Style.criticalBgColor : Style.surfaceLowColor
        Behavior on color { ColorAnimation { duration: 200 } }

        // ── Recording state ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root._recording

            // Pulsing red dot
            Rectangle {
                Layout.preferredWidth:  10
                Layout.preferredHeight: 10
                Layout.maximumWidth:    10
                Layout.alignment: Qt.AlignVCenter
                radius: 5
                color: Style.textCritical

                SequentialAnimation on opacity {
                    running: root._recording; loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 600 }
                    NumberAnimation { to: 1.0; duration: 600 }
                }
            }

            Text {
                text:           _fmt(root._elapsedSecs)
                color:          Style.textCritical
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeBody
                Layout.fillWidth: true
            }

            // Stop
            IconButton {
                label: "■"
                onClicked: if (root.screenrecProcess) root.screenrecProcess.stop()
            }
        }

        // ── Saved state ───────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root._showingSaved && !root._recording

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

    Process { id: _openProc;     command: ["xdg-open", root._savedPath] }
    Process { id: _copyPathProc; command: ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", root._savedPath] }
}
