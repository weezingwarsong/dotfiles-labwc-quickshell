import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell.Io

Item {
    id: root

    property var audioProcess:     null
    property var networkProcess:   null
    property var screenrecProcess: null

    property bool _audioCollapsed:   false
    property bool _networkCollapsed: false
    property bool _systemCollapsed:  true

    implicitHeight: _col.implicitHeight

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 10

        // ── Audio ─────────────────────────────────────────────────────────────
        PanelCard {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                SectionHeader {
                    Layout.fillWidth: true
                    text: "Audio"; tooltip: "Volume and mute controls"
                    collapsed: _audioCollapsed
                    onToggled: _audioCollapsed = !_audioCollapsed
                }

                Item {
                    Layout.fillWidth: true; clip: true
                    Layout.preferredHeight: !_audioCollapsed ? _audioRow.implicitHeight + 8 : 0
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    RowLayout {
                        id: _audioRow
                        anchors {
                            left: parent.left; right: parent.right; top: parent.top
                            topMargin: 8
                        }
                        spacing: 8

                        ScrollChip {
                            Layout.fillWidth: true
                            variant: "bar"
                            value:  root.audioProcess ? root.audioProcess.sourceVolume : 0
                            muted:  root.audioProcess ? root.audioProcess.sourceMuted  : false
                            label:  root.audioProcess ? root.audioProcess.sourceName   : "—"
                            glyph:  "🎤"
                            onScrolled:     (d) => { if (root.audioProcess) root.audioProcess.setSourceVolume(d * 0.05) }
                            onClicked:      if (root.audioProcess) root.audioProcess.toggleSourceMute()
                            onRightClicked: _pavuProc.running = true
                        }

                        ScrollChip {
                            Layout.fillWidth: true
                            variant: "bar"
                            value:  root.audioProcess ? root.audioProcess.sinkVolume : 0
                            muted:  root.audioProcess ? root.audioProcess.sinkMuted  : false
                            label:  root.audioProcess ? root.audioProcess.sinkName   : "—"
                            glyph:  "🎧"
                            onScrolled:     (d) => { if (root.audioProcess) root.audioProcess.setSinkVolume(d * 0.05) }
                            onClicked:      if (root.audioProcess) root.audioProcess.toggleSinkMute()
                            onRightClicked: _pavuProc.running = true
                        }
                    }
                }
            }
        }

        // ── Network ───────────────────────────────────────────────────────────
        PanelCard {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                SectionHeader {
                    Layout.fillWidth: true
                    text: "Network"; tooltip: "Connection status and controls"
                    collapsed: _networkCollapsed
                    onToggled: _networkCollapsed = !_networkCollapsed
                }

                Item {
                    Layout.fillWidth: true; clip: true
                    Layout.preferredHeight: !_networkCollapsed ? _networkRows.implicitHeight + 8 : 0
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: _networkRows
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Style.buttonHeight
                            radius: Style.panelElementRadius
                            color:  _netHover.hovered ? Style.surfaceLowColor : Style.surfaceMidColor
                            border.width: Style.elementBorderWidth
                            border.color: Style.borderSoftColor

                            HoverHandler { id: _netHover }

                            Text {
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    margins: 6
                                }
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
            }
        }

        // ── System ────────────────────────────────────────────────────────────
        PanelCard {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                SectionHeader {
                    Layout.fillWidth: true
                    text: "System"; tooltip: "System resource usage"
                    collapsed: _systemCollapsed
                    onToggled: _systemCollapsed = !_systemCollapsed
                }

                Item {
                    Layout.fillWidth: true; clip: true
                    Layout.preferredHeight: !_systemCollapsed ? _systemRows.implicitHeight + 8 : 0
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        id: _systemRows
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 120
                            radius: Style.panelElementRadius
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
                    }
                }
            }
        }

        // ── Screenrec section ─────────────────────────────────────────────────
        PanelDivider {}

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            SectionLabel { text: "Screen Recorder" }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                PanelButton {
                    Layout.fillWidth: true
                    label: "Screen"
                    variant: root._recMode === "screen" ? "accent" : "default"
                    enabled: !(root.screenrecProcess && root.screenrecProcess.recording)
                    onClicked: root._recMode = "screen"
                }
                PanelButton {
                    Layout.fillWidth: true
                    label: "Region"
                    variant: root._recMode === "region" ? "accent" : "default"
                    enabled: !(root.screenrecProcess && root.screenrecProcess.recording)
                    onClicked: root._recMode = "region"
                }
                PanelButton {
                    Layout.fillWidth: true
                    label: "Window"
                    variant: "default"
                    enabled: false
                    QQC.ToolTip.text: "Not available on Wayland (TBD)"
                    QQC.ToolTip.visible: _winHover.hovered
                    QQC.ToolTip.delay: 400
                    HoverHandler { id: _winHover }
                }
            }

            // Region start is disabled here — slurp can't get pointer grab as a QML child.
            // Use W+Shift+E keybind instead (calls pillbox-screenrec-region as labwc child).
            PanelButton {
                id: _startBtn
                Layout.fillWidth: true
                variant: (root.screenrecProcess && root.screenrecProcess.recording) ? "critical" : "accent"
                label: {
                    if (root.screenrecProcess && root.screenrecProcess.recording) return "Recording..."
                    if (root._recMode === "region") return "Pick Region & Start"
                    return "Start — Screen"
                }
                enabled: root.screenrecProcess !== null &&
                         ((root.screenrecProcess && root.screenrecProcess.recording) ||
                          root._recMode !== "region")
                QQC.ToolTip.text: "Use W+Shift+E to pick region"
                QQC.ToolTip.visible: root._recMode === "region" &&
                                     !(root.screenrecProcess && root.screenrecProcess.recording) &&
                                     _startBtnHover.hovered
                QQC.ToolTip.delay: 300
                HoverHandler { id: _startBtnHover }
                onClicked: {
                    if (!root.screenrecProcess) return
                    if (root.screenrecProcess.recording) {
                        root.screenrecProcess.stop()
                    } else {
                        root.screenrecProcess.startScreen()
                    }
                }
            }
        }

        // ── Session ───────────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: Style.buttonHeight

            RowLayout {
                anchors.fill: parent
                visible: root._pendingAction === ""
                spacing: 4

                Item { Layout.fillWidth: true }

                PanelButton { icon: "󰒓"; tooltip: "Reconfigure"; onClicked: _reconfigProc.running = true }
                PanelButton { icon: "󰍃"; tooltip: "Exit";        onClicked: root._startCountdown("exit") }
                PanelButton { icon: "󰜉"; tooltip: "Reboot";      onClicked: root._startCountdown("reboot") }
                PanelButton { icon: "󰐥"; tooltip: "Shutdown"; variant: "critical"; onClicked: root._startCountdown("shutdown") }
            }

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

                PanelButton { label: "Cancel"; onClicked: root._pendingAction = "" }
            }
        }
    }

    // ── Screenrec state ───────────────────────────────────────────────────────
    property string _recMode: "screen"   // "screen" | "region"

    // ── Session state ─────────────────────────────────────────────────────────
    property string _pendingAction:    ""
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
    Process { id: _pavuProc;      command: ["pavucontrol-qt"] }
    Process { id: _nmConnProc;    command: ["nm-connection-editor"] }
    Process { id: _reconfigProc;  command: ["labwc", "--reconfigure"] }
    Process { id: _exitProc;      command: ["labwc", "--exit"] }
    Process { id: _rebootProc;    command: ["systemctl", "reboot"] }
    Process { id: _shutdownProc;  command: ["systemctl", "poweroff"] }
}
