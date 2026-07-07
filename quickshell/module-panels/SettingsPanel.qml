import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    // ── Injected processes ────────────────────────────────────────────────────
    property var settingsProcess:  null
    property var calendarProcess:  null
    property var tasksProcess:     null

    implicitHeight: _col.implicitHeight + 24

    // ── Local state ───────────────────────────────────────────────────────────
    property string _locationDraft: settingsProcess ? settingsProcess.locationString : ""
    property bool   _revoking:      false

    // ── Revoke process ────────────────────────────────────────────────────────
    // Runs gcal-fetch --revoke on disconnect; then updates SettingsProcess state.
    Process {
        id: revokeProcess
        command: ["gcal-fetch", "--revoke"]
        stdout: SplitParser { onRead: function(line) {} }  // discard output
        onExited: function(code, signal) {
            root._revoking = false
            // Delete log file regardless of revocation result
            clearLogProcess.running = true
            root.settingsProcess.disconnect()
            console.log("[SettingsPanel] revoke exited:", code)
        }
    }

    Process {
        id: clearLogProcess
        command: ["sh", "-c", "rm -f /tmp/pillbox-google.log"]
        running: false
    }

    // Sends the re-auth notification (handles terminal detection internally).
    Process {
        id: authNotifyProcess
        command: ["google-auth-notify"]
        running: false
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _calendarStatus() {
        if (!settingsProcess || !settingsProcess.googleConnected) return ""
        if (!calendarProcess) return ""
        if (calendarProcess.lastError === "auth")    return "Auth error"
        if (calendarProcess.lastError === "network") return "Network error"
        if (calendarProcess.lastUpdated !== "")
            return "Last fetched " + calendarProcess.lastUpdated.substring(11, 16)
        return "Fetching…"
    }

    function _tasksStatus() {
        if (!settingsProcess || !settingsProcess.googleConnected) return ""
        if (!tasksProcess) return ""
        if (tasksProcess.lastError === "auth")    return "Auth error"
        if (tasksProcess.lastError === "network") return "Network error"
        if (tasksProcess.lastUpdated !== "")
            return "Last fetched " + tasksProcess.lastUpdated.substring(11, 16)
        return "Fetching…"
    }

    function _calendarStatusColor() {
        if (!calendarProcess) return Style.textMuted
        if (calendarProcess.lastError === "auth")    return Style.textCritical
        if (calendarProcess.lastError === "network") return Style.textLight
        return Style.textLight
    }

    function _tasksStatusColor() {
        if (!tasksProcess) return Style.textMuted
        if (tasksProcess.lastError === "auth")    return Style.textCritical
        if (tasksProcess.lastError === "network") return Style.textLight
        return Style.textLight
    }

    // ── Layout ────────────────────────────────────────────────────────────────

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 12

        // ── Google Account ────────────────────────────────────────────────────

        Text {
            text: "Google Account"
            color: Style.textPrimary
            font.family: Style.fontMono
            font.pixelSize: Style.fontHeaderSize
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            color: Style.surfaceLowColor
            radius: Style.panelBorderRadius
            implicitHeight: _googleCol.implicitHeight + 16

            ColumnLayout {
                id: _googleCol
                anchors { left: parent.left; right: parent.right; margins: 12; verticalCenter: parent.verticalCenter }
                spacing: 8

                // Status row
                RowLayout {
                    spacing: 6
                    Text {
                        text: (settingsProcess && settingsProcess.googleConnected)
                            ? "●" : "○"
                        color: (settingsProcess && settingsProcess.googleConnected)
                            ? Style.textSuccess : Style.textMuted
                        font.family: Style.fontMono
                        font.pixelSize: Style.fontContentSize
                    }
                    Text {
                        text: (settingsProcess && settingsProcess.googleConnected)
                            ? "Connected" : "Not connected"
                        color: Style.textNormal
                        font.family: Style.fontMono
                        font.pixelSize: Style.fontContentSize
                    }
                }

                // Per-service rows (only when connected)
                ColumnLayout {
                    visible: settingsProcess && settingsProcess.googleConnected
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "Calendar"
                            color: Style.textLight
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontContentSize
                            Layout.minimumWidth: 60
                        }
                        Text {
                            text: root._calendarStatus()
                            color: root._calendarStatusColor()
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontContentSize
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "Tasks"
                            color: Style.textLight
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontContentSize
                            Layout.minimumWidth: 60
                        }
                        Text {
                            text: root._tasksStatus()
                            color: root._tasksStatusColor()
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontContentSize
                        }
                    }
                }

                // Action buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Re-authenticate / Connect button
                    Rectangle {
                        implicitWidth: _authLabel.implicitWidth + 16
                        implicitHeight: 22
                        radius: Style.radButton
                        color: Style.surfaceMidColor

                        Text {
                            id: _authLabel
                            anchors.centerIn: parent
                            text: (settingsProcess && settingsProcess.googleConnected)
                                ? "Re-authenticate" : "Connect"
                            color: Style.textButton
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontContentSize
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (settingsProcess && !settingsProcess.googleConnected)
                                    settingsProcess.reconnect()
                                authNotifyProcess.running = true
                            }
                        }
                    }

                    // Disconnect button (only when connected)
                    Rectangle {
                        visible: settingsProcess && settingsProcess.googleConnected
                        implicitWidth: _disconnectLabel.implicitWidth + 16
                        implicitHeight: 22
                        radius: Style.radButton
                        color: root._revoking ? Style.surfaceLowColor : Style.surfaceMidColor

                        Text {
                            id: _disconnectLabel
                            anchors.centerIn: parent
                            text: root._revoking ? "Disconnecting…" : "Disconnect"
                            color: root._revoking ? Style.textMuted : Style.textCritical
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontContentSize
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root._revoking
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root._revoking = true
                                revokeProcess.running = true
                            }
                        }
                    }
                }
            }
        }

        // ── Divider ───────────────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Style.panelDividerColor
        }

        // ── Weather Location ──────────────────────────────────────────────────

        Text {
            text: "Weather Location"
            color: Style.textPrimary
            font.family: Style.fontMono
            font.pixelSize: Style.fontHeaderSize
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            color: Style.surfaceLowColor
            radius: Style.panelBorderRadius
            implicitHeight: _weatherCol.implicitHeight + 16

            ColumnLayout {
                id: _weatherCol
                anchors { left: parent.left; right: parent.right; margins: 12; verticalCenter: parent.verticalCenter }
                spacing: 8

                // Auto / Manual toggle
                RowLayout {
                    spacing: 6

                    Repeater {
                        model: ["Auto", "Manual"]
                        Rectangle {
                            required property string modelData
                            readonly property bool _active: settingsProcess
                                && settingsProcess.locationMode === modelData.toLowerCase()
                            implicitWidth: _modeLabel.implicitWidth + 16
                            implicitHeight: 22
                            radius: Style.radButton
                            color: _active ? Style.accentBgColor : Style.surfaceMidColor

                            Text {
                                id: _modeLabel
                                anchors.centerIn: parent
                                text: modelData
                                color: _active ? Style.textPrimary : Style.textButton
                                font.family: Style.fontMono
                                font.pixelSize: Style.fontContentSize
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (settingsProcess)
                                        settingsProcess.setLocationMode(modelData.toLowerCase())
                                }
                            }
                        }
                    }
                }

                // Manual input row
                RowLayout {
                    visible: settingsProcess && settingsProcess.locationMode === "manual"
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 22
                        radius: Style.radButton
                        color: Style.surfaceMidColor

                        TextInput {
                            id: _locationInput
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                            text: root._locationDraft
                            color: Style.textNormal
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontContentSize
                            selectByMouse: true
                            clip: true

                            Text {
                                visible: !parent.text && !parent.activeFocus
                                anchors.fill: parent
                                text: "City name or lat,lon"
                                color: Style.textDim
                                font.family: Style.fontMono
                                font.pixelSize: Style.fontContentSize
                                verticalAlignment: Text.AlignVCenter
                            }

                            onTextChanged: root._locationDraft = text
                            onAccepted: _applyLocation()
                        }
                    }

                    Rectangle {
                        implicitWidth: _applyLabel.implicitWidth + 16
                        implicitHeight: 22
                        radius: Style.radButton
                        color: Style.surfaceMidColor

                        Text {
                            id: _applyLabel
                            anchors.centerIn: parent
                            text: "Apply"
                            color: Style.textButton
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontContentSize
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: _applyLocation()
                        }
                    }
                }
            }
        }

        // Bottom spacer so last card doesn't clip the panel border
        Item { implicitHeight: 0 }
    }

    function _applyLocation() {
        if (settingsProcess && _locationDraft.trim() !== "")
            settingsProcess.setLocationString(_locationDraft.trim())
    }
}
