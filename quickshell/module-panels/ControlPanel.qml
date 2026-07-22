import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "./system-graphs"

Item {
    id: root
    focus: true
    Component.onCompleted: forceActiveFocus()

    property var audioProcess:     null
    property var networkProcess:   null
    property var screenrecProcess: null
    property var systemProcess:    null

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Up:
            if (root.audioProcess) root.audioProcess.setSinkVolume(0.05)
            event.accepted = true; break
        case Qt.Key_Down:
            if (root.audioProcess) root.audioProcess.setSinkVolume(-0.05)
            event.accepted = true; break
        case Qt.Key_M:
            if (root.audioProcess) root.audioProcess.toggleSinkMute()
            event.accepted = true; break
        case Qt.Key_N:
            if (root.networkProcess) root.networkProcess.toggleNetworking()
            event.accepted = true; break
        case Qt.Key_K:
            _systemCollapsed = !_systemCollapsed
            event.accepted = true; break
        case Qt.Key_R:
            root._fifo("screenrecSetMode:" + (Prefs.recMode === "replay" ? "oneshot" : "replay"))
            event.accepted = true; break
        case Qt.Key_A:
            if (Prefs.recMode !== "replay") {
                var modes = ["none", "system", "mic", "both"]
                var cur   = modes.indexOf(Prefs.recAudio)
                var next  = modes[(cur < 0 ? 0 : cur + 1) % modes.length]
                root._fifo("screenrecSetAudio:" + next)
                event.accepted = true
            } else {
                event.accepted = false
            }
            break
        default:
            event.accepted = false
        }
    }

    property bool _audioCollapsed:   false
    property bool _networkCollapsed: false
    property bool _systemCollapsed:  true

    implicitHeight: _flickable.contentHeight + _sessionRow.implicitHeight + 10

    // ── Scrollable panel cards ─────────────────────────────────────────────────
    Flickable {
        id: _flickable
        anchors {
            left:         parent.left
            right:        parent.right
            top:          parent.top
            bottom:       _sessionRow.top
            bottomMargin: 10
        }
        contentWidth:       width
        contentHeight:      _col.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior:     Flickable.StopAtBounds
        clip:               true

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                var delta = event.angleDelta.y * 0.5
                _flickable.contentY = Math.max(0, Math.min(
                    Math.max(0, _flickable.contentHeight - _flickable.height),
                    _flickable.contentY - delta
                ))
                event.accepted = true
            }
        }

        ColumnLayout {
            id: _col
            width:   parent.width
            spacing: 10

            // ── Audio ─────────────────────────────────────────────────────────
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

            // ── Network ───────────────────────────────────────────────────────
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

            // ── System ────────────────────────────────────────────────────────
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
                        Layout.preferredWidth: parent.width * 0.6
                        Layout.alignment:      Qt.AlignHCenter
                        clip:                  true
                        Layout.preferredHeight: !_systemCollapsed ? _sysGrid.implicitHeight : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        GridLayout {
                            id: _sysGrid
                            anchors { left: parent.left; right: parent.right; top: parent.top; }
                            columns:       2
                            columnSpacing: 2
                            rowSpacing:    2

                            SystemGraph {
                                Layout.fillWidth:       true
                                Layout.preferredHeight: (_sysGrid.width - _sysGrid.columnSpacing) / 2
                                value: root.systemProcess ? root.systemProcess.cpuValue  : 0.0
                                label: "CPU"
                            }
                            SystemGraph {
                                Layout.fillWidth:       true
                                Layout.preferredHeight: (_sysGrid.width - _sysGrid.columnSpacing) / 2
                                value: root.systemProcess ? root.systemProcess.memValue  : 0.0
                                label: "MEM"
                            }
                            SystemGraph {
                                Layout.fillWidth:       true
                                Layout.preferredHeight: (_sysGrid.width - _sysGrid.columnSpacing) / 2
                                value: root.systemProcess ? root.systemProcess.gpuValue  : 0.0
                                label: "GPU"
                            }
                            SystemGraph {
                                Layout.fillWidth:       true
                                Layout.preferredHeight: (_sysGrid.width - _sysGrid.columnSpacing) / 2
                                value: root.systemProcess ? root.systemProcess.diskValue : 0.0
                                label: "DISK"
                            }
                        }
                    }
                }
            }

            // ── Screenrec ─────────────────────────────────────────────────────
            PanelCard {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text:      "Screen Recorder"
                        collapsed: root._recCollapsed
                        onToggled: root._recCollapsed = !root._recCollapsed
                    }

                    Item {
                        Layout.fillWidth: true; clip: true
                        Layout.preferredHeight: !root._recCollapsed ? _recContent.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _recContent
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            spacing: 8

                            RowLayout {
                                id: _recRow
                                Layout.fillWidth: true
                                spacing: Style.panelElementHpadding

                                // Col 1 — Mode picker (writes screenrecSetMode:* to FIFO)
                                TogglePair {
                                    labelA:   "Single"
                                    labelB:   "Replay"
                                    selected: Prefs.recMode === "replay" ? 1 : 0
                                    enabled:  !(root.screenrecProcess && root.screenrecProcess.recording)
                                    onToggled: (idx) => root._fifo("screenrecSetMode:" + (idx === 1 ? "replay" : "oneshot"))
                                }

                                // Col 2 — mode-dependent context (fills remaining space)
                                PanelButton {
                                    Layout.fillWidth: true
                                    visible:  Prefs.recMode !== "replay"
                                    label:    "Region Pick"
                                    enabled:  !(root.screenrecProcess && root.screenrecProcess.recording)
                                    onClicked: _regionProc.running = true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible:        Prefs.recMode === "replay"
                                    text:           "W-S-e: capture replay"
                                    color:          Style.textMuted
                                    font.family:    Style.fontMono
                                    font.pixelSize: Style.fontSizeSubtle
                                    verticalAlignment: Text.AlignVCenter
                                }

                                // Col 3 — replay save duration
                                ScrollChip {
                                    visible: Prefs.recMode === "replay"
                                    variant: "value"
                                    text:    root._replaySaveLabel(Prefs.replaySaveDefaultSecs)
                                    onScrolled: (delta) => {
                                        var steps = [10, 30, 60, 300, 600, 1800]
                                        var cur = steps.indexOf(Prefs.replaySaveDefaultSecs)
                                        if (cur < 0) cur = 1
                                        var next = Math.max(0, Math.min(steps.length - 1, cur + (delta > 0 ? 1 : -1)))
                                        Prefs.setReplaySaveDefaultSecs(steps[next])
                                    }
                                }

                                // Col 4 — Start / Stop (writes screenrecToggle to FIFO)
                                TogglePair {
                                    readonly property bool _rec:
                                        root.screenrecProcess && root.screenrecProcess.recording
                                    labelA:     "■"
                                    labelB:     "󰑊"
                                    fontFamily: Style.fontNerd
                                    colorA:     _rec ? Style.textSuccess : Style.textMuted
                                    colorB:     Style.textCritical
                                    selected:   _rec ? 1 : 0
                                    onToggled:  (idx) => root._fifo("screenrecToggle")
                                }
                            }

                            // Row 2 — Audio source picker
                            // Hidden while replay daemon is active: audio flags are baked at spawn
                            // time and can't change while gsr is running without losing the buffer.
                            SegmentedControl {
                                Layout.fillWidth: true
                                visible:  !(Prefs.recMode === "replay" && root.screenrecProcess && root.screenrecProcess.active)
                                model:    ["None", "System", "Mic", "Both"]
                                selected: {
                                    var i = ["none", "system", "mic", "both"].indexOf(Prefs.recAudio)
                                    return i >= 0 ? i : 0
                                }
                                onToggled: (idx) => Prefs.setRecAudio(["none", "system", "mic", "both"][idx])
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Session — pinned at bottom ────────────────────────────────────────────
    PanelCard {
        id: _sessionRow
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }

        Item {
            Layout.fillWidth: true
            implicitHeight:   Style.buttonHeight

            RowLayout {
                anchors.fill: parent
                visible: root._pendingAction === ""
                spacing: 4

                SectionLabel { text: "Session" }
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

                SectionLabel { text: "Session" }

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
    property bool _recCollapsed: false

    function _replaySaveLabel(secs) {
        if (secs < 60)  return secs + "s"
        if (secs < 3600) return (secs / 60) + "m"
        return (secs / 3600) + "h"
    }

    // ── FIFO writer ───────────────────────────────────────────────────────────
    function _fifo(cmd) {
        _fifoProc.command = ["sh", "-c", "echo '" + cmd + "' > \"$HOME/.local/share/pillbox/pillbox.fifo\""]
        _fifoProc.running = true
    }
    Process { id: _fifoProc }

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
    Process { id: _regionProc;    command: ["pillbox-screenrec-region"] }
    Process { id: _reconfigProc;  command: ["labwc", "--reconfigure"] }
    Process { id: _exitProc;      command: ["sh", "-c", "loginctl terminate-session $XDG_SESSION_ID"] }
    Process { id: _rebootProc;    command: ["systemctl", "reboot"] }
    Process { id: _shutdownProc;  command: ["systemctl", "poweroff"] }
}
