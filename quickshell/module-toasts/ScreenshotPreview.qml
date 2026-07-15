import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property var screenshotProcess: null
    readonly property bool shouldShow: _visible

    property bool   _visible:  false
    property string _path:     ""
    property string _filename: ""

    visible:        _visible
    implicitHeight: _visible ? _bg.implicitHeight : 0

    Connections {
        target: root.screenshotProcess
        function onScreenshotSaved(path) {
            root._path     = path
            root._filename = path.split("/").pop()
            root._visible  = true
            _autoTimer.running = true
        }
    }

    function _dismiss() {
        root._visible = false
        _autoTimer.running = false
    }

    ToastTimer {
        id: _autoTimer
        interval: 5000
        paused:   _hover.hovered
        onExpired: root._dismiss()
    }

    HoverHandler { id: _hover }
    TapHandler   { acceptedButtons: Qt.RightButton; onTapped: root._dismiss() }

    Rectangle {
        id: _bg
        anchors.fill:   parent
        radius:         Style.pillRadius
        color:          Style.pillBgColor
        border.color:   Style.borderFaintColor
        border.width:   Style.pillBorderWidth
        implicitHeight: _row.implicitHeight + 16

        RowLayout {
            id: _row
            anchors { fill: parent; margins: 8 }
            spacing: 8

            // Thumbnail — fills most of the width; height driven by aspect ratio
            MediaThumbnail {
                source:   root._path
                filename: root._filename
                Layout.preferredWidth: Math.round(parent.width * 0.65)
                onThumbnailClicked: {
                    if (root._path !== "") _openProc.running = true
                    root._dismiss()
                }
            }

            // Button column
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 4

                // × dismiss
                IconButton { label: "×"; onClicked: root._dismiss() }

                // copy image bytes
                IconButton {
                    label: ""
                    fontFamily: Style.fontNerd
                    onClicked: if (root._path !== "") _copyImgProc.running = true
                }

                // ⋮ open screenshots panel
                IconButton {
                    label: "⋮"
                    onClicked: { _fifoProc.running = true; root._dismiss() }
                }
            }
        }
    }

    Process { id: _openProc;    command: ["xdg-open", root._path] }
    Process { id: _copyImgProc; command: ["sh", "-c", "wl-copy -t image/png < \"$1\"", "sh", root._path] }
    Process { id: _fifoProc;    command: ["sh", "-c", "echo screenshotUI > ~/.local/share/pillbox/pillbox.fifo"] }
}
