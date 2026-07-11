import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    // ── Injected processes ────────────────────────────────────────────────────
    property var    settingsProcess:  null
    property var    calendarProcess:  null
    property var    tasksProcess:     null
    property string activePanel:      ""

    signal navigateRequested(int direction)

    implicitHeight: _col.implicitHeight + 24

    // ── Local state ───────────────────────────────────────────────────────────
    property string _locationDraft: settingsProcess ? settingsProcess.locationString : ""
    property bool   _revoking:      false
    property string _tab:           "services"  // "services" | "appearance"

    // ── Appearance draft state (live — writes directly to Prefs) ─────────────
    // radiusScale maps: 0 = none, 1 = subtle, 2 = default
    readonly property int _radiusChoice: {
        var s = Prefs.radiusScale
        if (s <= 0.0)  return 0
        if (s <= 0.5)  return 1
        return 2
    }
    // borderWidth maps: 0 = off, 1 = thin, 2 = thick
    // (values already align — no translation needed)

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

    Rectangle {
        anchors.fill: parent
        radius: Style.radLg
        color: Style.panelBgColor
        border.color: Style.panelBorderColor
        border.width: Style.borderWidth
        clip: true
    }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 12

        PanelNavBar { activePanel: root.activePanel; onNavigateRequested: (dir) => root.navigateRequested(dir) }

        // ── Tab bar ───────────────────────────────────────────────────────────

        TogglePair {
            labelA: "Services"
            labelB: "Appearance"
            selected: root._tab === "appearance" ? 1 : 0
            onToggled: (i) => root._tab = (i === 0 ? "services" : "appearance")
        }

        // ── Services tab ──────────────────────────────────────────────────────

        ColumnLayout {
            visible: root._tab === "services"
            Layout.fillWidth: true
            spacing: 12

            // Google Account
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

            PanelDivider {}

            // Weather Location
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
        }

        // ── Appearance tab ────────────────────────────────────────────────────

        ColumnLayout {
            visible: root._tab === "appearance"
            Layout.fillWidth: true
            spacing: 12

            // Typography
            Text {
                text: "Typography"
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

                    // Pill text size stepper
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Pill text"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        PanelButton {
                            label: "–"
                            onClicked: if (Prefs.fontSizePill > 10) Prefs.setFontSizePill(Prefs.fontSizePill - 1)
                        }
                        Text {
                            text: Prefs.fontSizePill
                            color: Style.textNormal
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            horizontalAlignment: Text.AlignHCenter
                            Layout.minimumWidth: 24
                        }
                        PanelButton {
                            label: "+"
                            onClicked: if (Prefs.fontSizePill < 18) Prefs.setFontSizePill(Prefs.fontSizePill + 1)
                        }
                    }

                    // Panel text size stepper
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Panel text"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        PanelButton {
                            label: "–"
                            onClicked: if (Prefs.fontSizeBase > 8) Prefs.setFontSizeBase(Prefs.fontSizeBase - 1)
                        }
                        Text {
                            text: Prefs.fontSizeBase
                            color: Style.textNormal
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            horizontalAlignment: Text.AlignHCenter
                            Layout.minimumWidth: 24
                        }
                        PanelButton {
                            label: "+"
                            onClicked: if (Prefs.fontSizeBase < 14) Prefs.setFontSizeBase(Prefs.fontSizeBase + 1)
                        }
                    }

                    PanelDivider {}

                    // Mono font input
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Mono font"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 22
                            radius: Style.radSm
                            color: Style.surfaceMidColor
                            border.width: Style.elementBorderWidth
                            border.color: Style.borderSoftColor

                            TextInput {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 6; rightMargin: 6 }
                                text: Prefs.fontMono
                                color: Style.textNormal
                                font.family: Style.fontMono
                                font.pixelSize: Style.fontSizeBody
                                selectByMouse: true
                                clip: true
                                onEditingFinished: Prefs.setFontMono(text)
                            }
                        }
                    }

                    // Glyph font input
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Glyph font"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 22
                            radius: Style.radSm
                            color: Style.surfaceMidColor
                            border.width: Style.elementBorderWidth
                            border.color: Style.borderSoftColor

                            TextInput {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 6; rightMargin: 6 }
                                text: Prefs.fontNerd
                                color: Style.textNormal
                                font.family: Style.fontMono
                                font.pixelSize: Style.fontSizeBody
                                selectByMouse: true
                                clip: true
                                onEditingFinished: Prefs.setFontNerd(text)
                            }
                        }
                    }
                }
            }

            // Corner rounding
            Text {
                text: "Corner rounding"
                color: Style.textPrimary
                font.family: Style.fontMono
                font.pixelSize: Style.fontSizeHeading
                font.bold: true
            }

            PanelCard {
                RowLayout {
                    y: parent.padding
                    anchors { left: parent.left; right: parent.right; margins: parent.padding }
                    spacing: 6
                    PanelButton {
                        label: "None"
                        variant: root._radiusChoice === 0 ? "accent" : "default"
                        Layout.fillWidth: true
                        onClicked: Prefs.setRadiusScale(0.0)
                    }
                    PanelButton {
                        label: "Subtle"
                        variant: root._radiusChoice === 1 ? "accent" : "default"
                        Layout.fillWidth: true
                        onClicked: Prefs.setRadiusScale(0.5)
                    }
                    PanelButton {
                        label: "Default"
                        variant: root._radiusChoice === 2 ? "accent" : "default"
                        Layout.fillWidth: true
                        onClicked: Prefs.setRadiusScale(1.0)
                    }
                }
            }

            // Borders
            Text {
                text: "Borders"
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

                    // Container border
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Container"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 72
                        }
                        PanelButton {
                            label: "Off"
                            variant: Prefs.borderWidth === 0 ? "accent" : "default"
                            Layout.fillWidth: true
                            onClicked: Prefs.setBorderWidth(0)
                        }
                        PanelButton {
                            label: "Thin"
                            variant: Prefs.borderWidth === 1 ? "accent" : "default"
                            Layout.fillWidth: true
                            onClicked: Prefs.setBorderWidth(1)
                        }
                        PanelButton {
                            label: "Thick"
                            variant: Prefs.borderWidth === 2 ? "accent" : "default"
                            Layout.fillWidth: true
                            onClicked: Prefs.setBorderWidth(2)
                        }
                    }

                    // Element border
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Elements"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 72
                        }
                        PanelButton {
                            label: "Off"
                            variant: Prefs.elementBorderWidth === 0 ? "accent" : "default"
                            Layout.fillWidth: true
                            onClicked: Prefs.setElementBorderWidth(0)
                        }
                        PanelButton {
                            label: "Thin"
                            variant: Prefs.elementBorderWidth === 1 ? "accent" : "default"
                            Layout.fillWidth: true
                            onClicked: Prefs.setElementBorderWidth(1)
                        }
                        PanelButton {
                            label: "Thick"
                            variant: Prefs.elementBorderWidth === 2 ? "accent" : "default"
                            Layout.fillWidth: true
                            onClicked: Prefs.setElementBorderWidth(2)
                        }
                    }
                }
            }

            // Theme
            Text {
                text: "Theme"
                color: Style.textPrimary
                font.family: Style.fontMono
                font.pixelSize: Style.fontSizeHeading
                font.bold: true
            }

            PanelCard {
                RowLayout {
                    y: parent.padding
                    anchors { left: parent.left; right: parent.right; margins: parent.padding }
                    spacing: 6
                    Text {
                        text: "Extract colors from wallpaper"
                        color: Style.textSecondary
                        font.family: Style.fontMono
                        font.pixelSize: Style.fontSizeBody
                        Layout.fillWidth: true
                    }
                    PanelButton {
                        label: Prefs.extractColors ? "On" : "Off"
                        variant: Prefs.extractColors ? "accent" : "default"
                        onClicked: {
                            if (Prefs.extractColors) {
                                Prefs.setExtractColors(false)
                                Prefs.clearColorOverrides()
                            } else {
                                Prefs.setExtractColors(true)
                            }
                        }
                    }
                }
            }

            // Reset
            PanelButton {
                label: "Reset to defaults"
                variant: "critical"
                onClicked: {
                    Prefs.setFontMono("JetBrainsMono Nerd Font")
                    Prefs.setFontNerd("JetBrainsMono Nerd Font")
                    Prefs.setFontSizePill(13)
                    Prefs.setFontSizeBase(10)
                    Prefs.setRadiusScale(1.0)
                    Prefs.setBorderWidth(1)
                    Prefs.setElementBorderWidth(1)
                    Prefs.setExtractColors(false)
                    Prefs.clearColorOverrides()
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
