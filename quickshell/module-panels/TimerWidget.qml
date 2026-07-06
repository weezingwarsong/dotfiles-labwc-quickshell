import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property var  timerProcess:   null
    property bool _inputExpanded: false

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
                    font.pixelSize: Style.fontTimerSize
                    font.family: Style.fontMono
                    verticalAlignment: Text.AlignBottom
                }
                Text {
                    text: root.timerProcess ? root.timerProcess.displayCenti : ""
                    color: Style.textSubtle
                    font.pixelSize: Math.round(Style.fontTimerSize * 0.55)
                    font.family: Style.fontMono
                    height: mainTime.implicitHeight
                    verticalAlignment: Text.AlignBottom
                    visible: root.timerProcess && root.timerProcess.displayCenti !== ""
                }
            }
        }

        // Row 1: Mode toggle + Start/Stop
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                height: 20; radius: Style.radButtonSmall
                color: modeHover.containsMouse ? Style.surfaceLowColor : "transparent"
                border.color: Style.borderFaintColor; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: root.timerProcess && root.timerProcess.mode === "stopwatch" ? "Countup" : "Countdown"
                    color: Style.textDim; font.pixelSize: Style.fontGridNumSize
                }
                MouseArea {
                    id: modeHover; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        if (!root.timerProcess) return
                        if (root.timerProcess.mode === "stopwatch") root.timerProcess.setMode("timer")
                        else                                         root.timerProcess.setMode("stopwatch")
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 20; radius: Style.radButtonSmall
                color: startHover.containsMouse ? Style.accentBgHover : Style.accentBgColor
                border.color: Style.borderAccentColor; border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: root.timerProcess && root.timerProcess.active ? "Stop" : "Start"
                    color: Style.textAccentColor; font.pixelSize: Style.fontContentSize
                }
                MouseArea {
                    id: startHover; anchors.fill: parent; hoverEnabled: true
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
            }
        }

        // Row 2: Duration button (countdown only) + Reset
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                id: durationBtn
                Layout.fillWidth: true
                height: 20; radius: Style.radButtonSmall
                visible: !root.timerProcess || root.timerProcess.mode !== "stopwatch"
                color: durationHover.containsMouse ? Style.surfaceMidColor : Style.surfaceLowColor
                border.color: root._inputExpanded ? Style.borderAccentColor : Style.borderSoftColor
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: root.timerProcess ? root._formatDuration(root.timerProcess.duration) : "1m:30s"
                    color: Style.textButton; font.pixelSize: Style.fontContentSize
                }
                MouseArea {
                    id: durationHover; anchors.fill: parent; hoverEnabled: true
                    onClicked: root._inputExpanded = !root._inputExpanded
                }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        if (!root.timerProcess) return
                        var delta = event.angleDelta.y > 0 ? 5 : -5
                        root.timerProcess.setTimer(Math.max(5, root.timerProcess.duration + delta))
                        event.accepted = true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 20; radius: Style.radButtonSmall
                color: resetHover.containsMouse ? Style.surfaceMidColor : Style.surfaceLowColor
                border.color: Style.borderSoftColor; border.width: 1
                Text { anchors.centerIn: parent; text: "Reset"; color: Style.textButton; font.pixelSize: Style.fontContentSize }
                MouseArea {
                    id: resetHover; anchors.fill: parent; hoverEnabled: true
                    onClicked: {
                        if (!root.timerProcess) return
                        if (root.timerProcess.mode === "stopwatch") root.timerProcess.resetStopwatch()
                        else                                         root.timerProcess.resetTimer()
                    }
                }
            }
        }

        // Expandable duration input (countdown mode only)
        Rectangle {
            Layout.fillWidth: true
            height: 28; radius: Style.radButtonSmall
            visible: root._inputExpanded && (!root.timerProcess || root.timerProcess.mode !== "stopwatch")
            color: Style.surfaceLowColor
            border.color: Style.borderAccentColor; border.width: 1

            onVisibleChanged: if (visible) Qt.callLater(durationInput.forceActiveFocus)

            // Placeholder text
            Text {
                anchors.fill: parent; anchors.leftMargin: 8
                verticalAlignment: Text.AlignVCenter
                text: "e.g.  25m   1h:30m   1h:1m:30s"
                color: Style.textDim; font.pixelSize: Style.fontContentSize; font.family: Style.fontMono
                visible: durationInput.text === ""
            }

            TextInput {
                id: durationInput
                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Style.textNormal; font.pixelSize: Style.fontContentSize; font.family: Style.fontMono

                Keys.onReturnPressed: {
                    var secs = root._parseDuration(text)
                    if (secs > 0 && root.timerProcess) root.timerProcess.setTimer(secs)
                    root._inputExpanded = false
                    text = ""
                }
                Keys.onEscapePressed: {
                    root._inputExpanded = false
                    text = ""
                }
                onActiveFocusChanged: {
                    if (!activeFocus) { root._inputExpanded = false; text = "" }
                }
            }
        }
    }
}
