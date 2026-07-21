import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property var screenrecProcess: null

    readonly property bool shouldShow: root.screenrecProcess ? root.screenrecProcess.recording : false

    property int _elapsedSecs: 0

    visible:        shouldShow
    implicitHeight: shouldShow ? _card.implicitHeight : 0

    Connections {
        target: root.screenrecProcess
        function onRecordingStarted() {
            root._elapsedSecs = 0
            _elapsed.start()
        }
        function onRecordingStopped(path) { _elapsed.stop() }
        function onRecordingError(reason) { _elapsed.stop() }
    }

    Timer {
        id: _elapsed
        interval: 1000; repeat: true
        onTriggered: root._elapsedSecs++
    }

    PanelCard {
        id: _card
        anchors.fill: parent
        color: Style.criticalBgColor

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.preferredWidth:  10
                Layout.preferredHeight: 10
                Layout.maximumWidth:    10
                Layout.alignment: Qt.AlignVCenter
                radius: 5
                color:  Style.textCritical

                SequentialAnimation on opacity {
                    running: root.shouldShow; loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 600 }
                    NumberAnimation { to: 1.0; duration: 600 }
                }
            }

            Text {
                Layout.fillWidth: true
                text:           root._fmt(root._elapsedSecs)
                color:          Style.textCritical
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeBody
            }

            IconButton {
                label:     "■"
                onClicked: root._fifo("screenrecToggle")
            }
        }
    }

    function _fifo(cmd) {
        _fifoProc.command = ["sh", "-c",
            "echo '" + cmd + "' > \"$HOME/.local/share/pillbox/pillbox.fifo\""]
        _fifoProc.running = true
    }
    Process { id: _fifoProc }

    function _fmt(secs) {
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var s = secs % 60
        if (h > 0) return h + ":" + _p(m) + ":" + _p(s)
        return _p(m) + ":" + _p(s)
    }
    function _p(n) { return n < 10 ? "0" + n : "" + n }
}
