import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var  timerProcess:      null
    property bool _inputExpanded:    false
    property Item focusReturnTarget: null

    implicitHeight: layout.implicitHeight

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _formatDuration(secs) {
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var s = secs % 60
        var parts = []
        if (h > 0) parts.push(h + "h")
        if (m > 0) parts.push(m + "m")
        if (s > 0 || parts.length === 0) parts.push(s + "s")
        return parts.join(":")
    }

    function _parseDuration(str) {
        var s = str.trim()
        if (!s) return 0
        var h = 0, m = 0, sec = 0
        var hm  = s.match(/(\d+)\s*h/i)
        var mm  = s.match(/(\d+)\s*m(?!s)/i)
        var sm  = s.match(/(\d+)\s*s/i)
        if (hm || mm || sm) {
            if (hm)  h   = parseInt(hm[1])
            if (mm)  m   = parseInt(mm[1])
            if (sm)  sec = parseInt(sm[1])
        } else {
            var parts = s.split(":")
            if      (parts.length === 3) { h = parseInt(parts[0])||0; m = parseInt(parts[1])||0; sec = parseInt(parts[2])||0 }
            else if (parts.length === 2) { m = parseInt(parts[0])||0; sec = parseInt(parts[1])||0 }
            else                         { sec = parseInt(s) || 0 }
        }
        return Math.max(0, h * 3600 + m * 60 + sec)
    }

    // ── Layout ────────────────────────────────────────────────────────────────

    ColumnLayout {
        id: layout
        width: parent.width
        spacing: 8

        // Clock face: HH:MM:SS in large monospace + .cs in smaller text
        Item {
            Layout.fillWidth: true
            implicitHeight: mainTime.implicitHeight + 4

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    id: mainTime
                    text: root.timerProcess ? root.timerProcess.displayText : "00:01:30"
                    color: Style.textPrimary
                    font.pixelSize: 22
                    font.family: Style.fontMono
                    verticalAlignment: Text.AlignBottom
                }
                Text {
                    text: root.timerProcess ? root.timerProcess.displayCenti : ""
                    color: Style.textMuted
                    font.pixelSize: Math.round(22 * 0.55)
                    font.family: Style.fontMono
                    height: mainTime.implicitHeight
                    verticalAlignment: Text.AlignBottom
                    visible: root.timerProcess && root.timerProcess.displayCenti !== ""
                }
            }
        }

        // ── New 2×2 control grid ─────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns:       2
            rowSpacing:    6
            columnSpacing: 6

            // Cell 1 — Mode (TogglePair)
            TogglePair {
                Layout.fillWidth: true
                labelA:   "Countdown"
                labelB:   "Countup"
                selected: root.timerProcess && root.timerProcess.mode === "stopwatch" ? 1 : 0
                onToggled: (i) => {
                    if (!root.timerProcess) return
                    root.timerProcess.setMode(i === 0 ? "timer" : "stopwatch")
                }
            }

            // Cell 2 — Start/Stop (IconButton)
            IconButton {
                Layout.fillWidth: true
                label:   root.timerProcess && root.timerProcess.active
                         ? String.fromCodePoint(0xf04c)
                         : String.fromCodePoint(0xf04b)
                tooltip: root.timerProcess && root.timerProcess.active ? "Pause" : "Start"
                variant: root.timerProcess && root.timerProcess.active ? "important" : "default"
                onClicked: {
                    if (!root.timerProcess) return
                    if (root.timerProcess.mode === "stopwatch") {
                        if (root.timerProcess.active) root.timerProcess.stopStopwatch()
                        else                          root.timerProcess.startStopwatch()
                    } else {
                        if (root.timerProcess.active) root.timerProcess.pauseTimer()
                        else                          root.timerProcess.startTimer()
                    }
                }
            }

            // Cell 3 — Duration (ScrollChip, countdown only)
            ScrollChip {
                Layout.fillWidth: true
                variant: "bar"
                value:   0
                glyph:   ""
                label:   root.timerProcess ? root._formatDuration(root.timerProcess.duration) : "1m:30s"
                opacity: root.timerProcess && root.timerProcess.mode === "stopwatch" ? 0.35 : 1.0
                onScrolled: (d) => {
                    if (!root.timerProcess || root.timerProcess.mode === "stopwatch") return
                    root.timerProcess.setTimer(Math.max(5, root.timerProcess.duration + d * 5))
                }
                onClicked: {
                    if (!root.timerProcess || root.timerProcess.mode === "stopwatch") return
                    root._inputExpanded = !root._inputExpanded
                }
            }

            // Cell 4 — Reset (PanelButton)
            PanelButton {
                Layout.fillWidth: true
                icon:    String.fromCodePoint(0xf0e2)
                label:   "Reset"
                onClicked: {
                    if (!root.timerProcess) return
                    if (root.timerProcess.mode === "stopwatch") root.timerProcess.resetStopwatch()
                    else                                         root.timerProcess.resetTimer()
                }
            }
        }

        // Expandable duration input (countdown mode only)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28; radius: Style.panelElementRadius
            visible: root._inputExpanded && (!root.timerProcess || root.timerProcess.mode !== "stopwatch")
            color: Style.surfaceLowColor
            border.color: Style.accentColor; border.width: 1

            onVisibleChanged: if (visible) Qt.callLater(durationInput.forceActiveFocus)

            // Placeholder text
            Text {
                anchors.fill: parent; anchors.leftMargin: 8
                verticalAlignment: Text.AlignVCenter
                text: "e.g.  25m   1h:30m   1h:1m:30s"
                color: Style.textMuted; font.pixelSize: Style.fontSizeBody; font.family: Style.fontMono
                visible: durationInput.text === ""
            }

            TextInput {
                id: durationInput
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Style.textNormal; font.pixelSize: Style.fontSizeBody; font.family: Style.fontMono

                Keys.onReturnPressed: _submit()
                Keys.onEnterPressed:  _submit()

                function _submit() {
                    var secs = root._parseDuration(text)
                    if (secs > 0 && root.timerProcess) {
                        root.timerProcess.setTimer(secs)
                        root.timerProcess.startTimer()
                    }
                    root._inputExpanded = false
                    text = ""
                    if (root.focusReturnTarget) root.focusReturnTarget.forceActiveFocus()
                }
                Keys.onEscapePressed: {
                    root._inputExpanded = false
                    text = ""
                    if (root.focusReturnTarget) root.focusReturnTarget.forceActiveFocus()
                }
                onActiveFocusChanged: {
                    if (!activeFocus) {
                        root._inputExpanded = false
                        text = ""
                        if (root.focusReturnTarget) Qt.callLater(root.focusReturnTarget.forceActiveFocus)
                    }
                }
            }
        }
    }
}
