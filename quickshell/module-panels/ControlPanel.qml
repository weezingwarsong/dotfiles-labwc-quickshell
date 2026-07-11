import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell.Io

Item {
    id: root

    property var audioProcess:   null
    property var networkProcess: null
    signal navigateRequested(int direction)

    implicitHeight: _col.implicitHeight + 24

    Rectangle {
        anchors.fill: parent
        radius:       Style.radLg
        color:        Style.panelBgColor
        border.color: Style.panelBorderColor
        border.width: 1
        clip:         true
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 10

        PanelNavBar { onNavigateRequested: (dir) => root.navigateRequested(dir) }

        // ── Audio | Network ───────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // ── Volume column (left) ──────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                SectionLabel { text: "Audio" }

                // Source (mic)
                VolumeButton {
                    Layout.fillWidth: true
                    node: root.audioProcess ? root.audioProcess.source : null
                    onRightClicked: _pavuProc.running = true
                }

                // Sink (speaker)
                VolumeButton {
                    Layout.fillWidth: true
                    node: root.audioProcess ? root.audioProcess.sink : null
                    onRightClicked: _pavuProc.running = true
                }
            }

            Rectangle {
                width: 1
                Layout.fillHeight: true
                color: Style.panelDividerColor
            }

            // ── Network column (right) ────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                SectionLabel { text: "Network" }

                Rectangle {
                    Layout.fillWidth: true
                    height: Style.buttonHeight
                    radius: Style.radSm
                    color:  _netHover.hovered ? Style.surfaceLowColor : Style.surfaceMidColor
                    border.width: Style.elementBorderWidth
                    border.color: Style.borderSoftColor

                    HoverHandler { id: _netHover }

                    Text {
                        anchors.centerIn: parent
                        anchors.left:    parent.left
                        anchors.right:   parent.right
                        anchors.margins: 6
                        horizontalAlignment: Text.AlignHCenter
                        elide:           Text.ElideRight
                        text:  root.networkProcess && root.networkProcess.connected
                               ? root.networkProcess.localIp
                               : "No connection"
                        color: root.networkProcess && root.networkProcess.connected
                               ? Style.textSuccess
                               : Style.textCritical
                        font.family:    Style.fontMono
                        font.pixelSize: Style.fontSizeBody
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: if (root.networkProcess) root.networkProcess.toggleNetworking()
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: _nmConnProc.running = true
                    }
                }
            }
        }

        // ── System graphs placeholder (reserved for future) ───────────────────
        Rectangle {
            Layout.fillWidth:    true
            Layout.preferredHeight: 120
            radius: Style.radSm
            color:  Style.surfaceLowColor
            border.width: Style.elementBorderWidth
            border.color: Style.borderFaintColor

            Text {
                anchors.centerIn: parent
                text:           "System"
                color:          Style.textFaint
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeSubtle
            }
        }

        // ── Session row ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: Style.buttonHeight

            // Normal: four buttons right-aligned
            RowLayout {
                anchors.fill: parent
                visible: root._pendingAction === ""
                spacing: 4

                Item { Layout.fillWidth: true }

                PanelButton {
                    label: "Reconfigure"
                    onClicked: _reconfigProc.running = true
                }
                PanelButton {
                    label: "Exit"
                    onClicked: root._startCountdown("exit")
                }
                PanelButton {
                    label: "Reboot"
                    onClicked: root._startCountdown("reboot")
                }
                PanelButton {
                    label:    "Shutdown"
                    variant:  "critical"
                    onClicked: root._startCountdown("shutdown")
                }
            }

            // Confirm: countdown label + cancel
            RowLayout {
                anchors.fill: parent
                visible: root._pendingAction !== ""
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: {
                        var s = root._sessionRemaining
                        if (root._pendingAction === "exit")     return "Exiting in "       + s + "s..."
                        if (root._pendingAction === "reboot")   return "Rebooting in "     + s + "s..."
                        if (root._pendingAction === "shutdown") return "Shutting down in " + s + "s..."
                        return ""
                    }
                    color:          Style.textCritical
                    font.family:    Style.fontMono
                    font.pixelSize: Style.fontSizeBody
                    verticalAlignment: Text.AlignVCenter
                }

                PanelButton {
                    label: "Cancel"
                    onClicked: root._pendingAction = ""
                }
            }
        }
    }

    // ── Session state ─────────────────────────────────────────────────────────
    property string _pendingAction:    ""   // "" | "exit" | "reboot" | "shutdown"
    property real   _sessionStart:     0
    property int    _sessionRemaining: 3

    function _startCountdown(action) {
        root._pendingAction    = action
        root._sessionStart     = Date.now()
        root._sessionRemaining = 3
    }

    Timer {
        id: _sessionTimer
        interval: 100
        repeat:   true
        running:  root._pendingAction !== ""
        onTriggered: {
            var remaining = Math.ceil(3 - (Date.now() - root._sessionStart) / 1000)
            if (remaining <= 0) {
                var action = root._pendingAction
                root._pendingAction = ""
                if      (action === "exit")     _exitProc.running     = true
                else if (action === "reboot")   _rebootProc.running   = true
                else if (action === "shutdown") _shutdownProc.running = true
            } else {
                root._sessionRemaining = remaining
            }
        }
    }

    // ── Processes ─────────────────────────────────────────────────────────────
    Process { id: _pavuProc;    command: ["pavucontrol-qt"] }
    Process { id: _nmConnProc;  command: ["nm-connection-editor"] }
    Process { id: _reconfigProc; command: ["labwc", "--reconfigure"] }
    Process { id: _exitProc;     command: ["labwc", "--exit"] }
    Process { id: _rebootProc;   command: ["systemctl", "reboot"] }
    Process { id: _shutdownProc; command: ["systemctl", "poweroff"] }

    // ── Volume button (inline component) ─────────────────────────────────────
    component VolumeButton: Rectangle {
        id: _vb

        required property var node   // PwNode from AudioProcess (sink or source)
        signal rightClicked()

        height:       Style.buttonHeight
        radius:       Style.radSm
        color:        _vbHover.hovered ? Style.surfaceLowColor : Style.surfaceMidColor
        border.width: Style.elementBorderWidth
        border.color: node && node.audio.muted ? Style.accentColor : Style.borderSoftColor

        property bool _showVol: false

        Timer {
            id: _peekTimer
            interval: 1500
            onTriggered: _vb._showVol = false
        }

        HoverHandler { id: _vbHover }

        Text {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 6 }
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: {
                if (!_vb.node) return "—"
                if (_vb.node.audio.muted) return "MUTED"
                if (_vb._showVol) return Math.round(_vb.node.audio.volume * 100) + "%"
                var n = _vb.node
                return n.nickname !== "" ? n.nickname : n.description !== "" ? n.description : n.name
            }
            color:          _vb.node && _vb.node.audio.muted ? Style.textMuted : Style.textSecondary
            font.family:    Style.fontMono
            font.pixelSize: Style.fontSizeBody
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: if (_vb.node) _vb.node.audio.muted = !_vb.node.audio.muted
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: _vb.rightClicked()
        }

        WheelHandler {
            onWheel: (event) => {
                if (!_vb.node) return
                var delta = event.angleDelta.y > 0 ? 0.05 : -0.05
                _vb.node.audio.volume = Math.max(0, Math.min(1, _vb.node.audio.volume + delta))
                _vb._showVol = true
                _peekTimer.restart()
            }
        }
    }
}
