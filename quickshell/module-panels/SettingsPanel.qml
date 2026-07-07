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
    Process {
        id: revokeProcess
        command: ["gcal-fetch", "--revoke"]
        stdout: SplitParser { onRead: function(line) {} }
        onExited: function(code, signal) {
            root._revoking = false
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
        if (calendarProcess.lastError === "network") return Style.textSecondary
        return Style.textSecondary
    }

    function _tasksStatusColor() {
        if (!tasksProcess) return Style.textMuted
        if (tasksProcess.lastError === "auth")    return Style.textCritical
        if (tasksProcess.lastError === "network") return Style.textSecondary
        return Style.textSecondary
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
            font.pixelSize: Style.fontSizeHeading
            font.bold: true
        }

        PanelCard {
            ColumnLayout {
                y: parent.padding
                anchors { left: parent.left; right: parent.right; margins: parent.padding }
                spacing: 8

                RowLayout {
                    spacing: 6
                    StatusDot { active: settingsProcess && settingsProcess.googleConnected }
                    Text {
                        text: (settingsProcess && settingsProcess.googleConnected)
                            ? "Connected" : "Not connected"
                        color: Style.textNormal
                        font.family: Style.fontMono
                        font.pixelSize: Style.fontSizeBody
                    }
                }

                ColumnLayout {
                    visible: settingsProcess && settingsProcess.googleConnected
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "Calendar"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 60
                        }
                        Text {
                            text: root._calendarStatus()
                            color: root._calendarStatusColor()
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "Tasks"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 60
                        }
                        Text {
                            text: root._tasksStatus()
                            color: root._tasksStatusColor()
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    PanelButton {
                        label: (settingsProcess && settingsProcess.googleConnected)
                            ? "Re-authenticate" : "Connect"
                        variant: "accent"
                        onClicked: {
                            if (settingsProcess && !settingsProcess.googleConnected)
                                settingsProcess.reconnect()
                            authNotifyProcess.running = true
                        }
                    }

                    PanelButton {
                        visible: settingsProcess && settingsProcess.googleConnected
                        label: root._revoking ? "Disconnecting…" : "Disconnect"
                        variant: root._revoking ? "default" : "critical"
                        onClicked: {
                            if (!root._revoking) {
                                root._revoking = true
                                revokeProcess.running = true
                            }
                        }
                    }
                }
            }
        }

        // ── Divider ───────────────────────────────────────────────────────────

        PanelDivider {}

        // ── Weather Location ──────────────────────────────────────────────────

        Text {
            text: "Weather Location"
            color: Style.textPrimary
            font.family: Style.fontMono
            font.pixelSize: Style.fontSizeHeading
            font.bold: true
        }

        PanelCard {
            ColumnLayout {
                y: parent.padding
                anchors { left: parent.left; right: parent.right; margins: parent.padding }
                spacing: 8

                TogglePair {
                    labelA: "Auto"
                    labelB: "Manual"
                    selected: settingsProcess && settingsProcess.locationMode === "manual" ? 1 : 0
                    onToggled: (index) => {
                        if (settingsProcess)
                            settingsProcess.setLocationMode(index === 0 ? "auto" : "manual")
                    }
                }

                RowLayout {
                    visible: settingsProcess && settingsProcess.locationMode === "manual"
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 22
                        radius: Style.radSm
                        color: Style.surfaceMidColor

                        TextInput {
                            id: _locationInput
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                            text: root._locationDraft
                            color: Style.textNormal
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            selectByMouse: true
                            clip: true

                            Text {
                                visible: !parent.text && !parent.activeFocus
                                anchors.fill: parent
                                text: "City name or lat,lon"
                                color: Style.textMuted
                                font.family: Style.fontMono
                                font.pixelSize: Style.fontSizeBody
                                verticalAlignment: Text.AlignVCenter
                            }

                            onTextChanged: root._locationDraft = text
                            onAccepted: _applyLocation()
                        }
                    }

                    PanelButton {
                        label: "Apply"
                        onClicked: _applyLocation()
                    }
                }
            }
        }

        Item { implicitHeight: 0 }
    }

    function _applyLocation() {
        if (settingsProcess && _locationDraft.trim() !== "")
            settingsProcess.setLocationString(_locationDraft.trim())
    }
}
