import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property var screenrecProcess: null

    readonly property bool shouldShow: _visible

    property bool   _visible: false
    property string _path:    ""

    visible:        _visible
    implicitHeight: _visible ? _card.implicitHeight : 0

    Connections {
        target: root.screenrecProcess
        function onReplaySaved(path) {
            root._path    = path
            root._visible = true
            _toastTimer.start(Prefs.notificationTimeout)
        }
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

            Text {
                Layout.fillWidth: true
                text:           _replayLabel() + " Replay Captured"
                color:          Style.textNormal
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeBody
                elide:          Text.ElideRight
            }

            IconButton { label: "×"; onClicked: root._dismiss() }
            IconButton { label: "▶"; onClicked: if (root._path !== "") _openProc.running = true }
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

    function _replayLabel() {
        var s = Prefs.replaySaveDefaultSecs
        if (s < 60)   return s + "s"
        if (s < 3600) return (s / 60) + "m"
        return (s / 3600) + "h"
    }

    Process { id: _openProc; command: ["xdg-open", root._path] }
}
