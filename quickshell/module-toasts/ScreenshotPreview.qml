import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property var screenshotProcess: null
    readonly property bool shouldShow: _visible

    property bool   _visible:     false
    property bool   _showPreview: false
    property string _path:        ""
    property string _filename:    ""

    width:          parent.width
    visible:        _visible
    implicitHeight: _visible ? _card.implicitHeight : 0

    Connections {
        target: root.screenshotProcess
        function onScreenshotSaved(path) {
            root._path        = path
            root._filename    = path.split("/").pop()
            root._showPreview = false
            root._visible     = true
            _toastTimer.start(Prefs.notificationTimeout)
        }
    }

    function _dismiss() {
        _toastTimer.kill()
        root._showPreview = false
        root._visible     = false
    }

    function _multiMimeCopy() {
        if (_copyMultiProc.running) _copyMultiProc.running = false
        _copyMultiProc.running = true
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                if (_toastTimer.running) _toastTimer.pause()
            } else {
                if (root._showPreview) {
                    // Mouse left while preview was showing — dismiss
                    root._dismiss()
                } else if (_toastTimer.running) {
                    _toastTimer.resume()
                }
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
                source:   root._path
                filename: root._filename
                Layout.fillWidth: true
                onThumbnailClicked: {
                    if (root._path !== "") {
                        root._multiMimeCopy()
                        _toastTimer.kill()
                        root._showPreview = true
                    }
                }
                onFilenameClicked: {
                    if (root._path !== "") _copyPathProc.running = true
                    root._dismiss()
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 4

                IconButton { label: "×"; onClicked: root._dismiss() }

                IconButton {
                    label:      String.fromCodePoint(0xf0c5)
                    fontFamily: Style.fontNerd
                    onClicked:  if (root._path !== "") root._multiMimeCopy()
                }

                IconButton {
                    label: "⋮"
                    onClicked: { _fifoProc.running = true; root._dismiss() }
                }
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

    Process { id: _copyMultiProc; command: ["pillbox-copy-multi", root._path] }
    Process { id: _copyPathProc;  command: ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", root._path] }
    Process { id: _fifoProc;      command: ["sh", "-c", "echo screenshotUI > ~/.local/share/pillbox/pillbox.fifo"] }
}
