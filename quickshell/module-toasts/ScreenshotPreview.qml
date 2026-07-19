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
    property string _dir:      ""

    visible:        _visible
    implicitHeight: _visible ? _card.implicitHeight : 0

    Connections {
        target: root.screenshotProcess
        function onScreenshotSaved(path) {
            root._path     = path
            root._filename = path.split("/").pop()
            root._dir      = path.substring(0, path.lastIndexOf('/'))
            root._visible  = true
        }
    }

    function _dismiss() { root._visible = false }

    function _multiMimeCopy() {
        if (_copyMultiProc.running) _copyMultiProc.running = false
        _copyMultiProc.running = true
    }

    TapHandler { acceptedButtons: Qt.RightButton; onTapped: root._dismiss() }

    PanelCard {
        id: _card
        anchors.fill: parent

        RowLayout {
            id: _row
            Layout.fillWidth: true
            spacing: 8

            // Thumbnail — fills most of the width; height driven by aspect ratio
            MediaThumbnail {
                source:   root._path
                filename: root._filename
                Layout.preferredWidth: Math.round(parent.width * 0.65)
                onThumbnailClicked: {
                    if (root._path !== "") {
                        root._multiMimeCopy()
                        _openDirProc.running = true
                    }
                    root._dismiss()
                }
                onFilenameClicked: {
                    if (root._path !== "") _copyPathProc.running = true
                    root._dismiss()
                }
            }

            // Button column
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 4

                // × dismiss
                IconButton { label: "×"; onClicked: root._dismiss() }

                // multi-MIME copy (image/png + text/plain + text/uri-list)
                IconButton {
                    label:      String.fromCodePoint(0xf0c5)
                    fontFamily: Style.fontNerd
                    onClicked:  if (root._path !== "") root._multiMimeCopy()
                }

                // ⋮ open screenshots panel
                IconButton {
                    label: "⋮"
                    onClicked: { _fifoProc.running = true; root._dismiss() }
                }
            }
        }
    }

    // multi-MIME clipboard: image/png + text/plain (path) + text/uri-list
    Process { id: _copyMultiProc; command: ["pillbox-copy-multi", root._path] }
    // open directory in file manager
    Process { id: _openDirProc;   command: ["xdg-open", root._dir] }
    // plain text path for filename-overlay click
    Process { id: _copyPathProc;  command: ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", root._path] }
    // send screenshotUI FIFO signal to open screenshots panel
    Process { id: _fifoProc;      command: ["sh", "-c", "echo screenshotUI > ~/.local/share/pillbox/pillbox.fifo"] }
}
