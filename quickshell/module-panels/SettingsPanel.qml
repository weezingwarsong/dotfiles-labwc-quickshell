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
    property string _tab:           "appearance"  // "appearance" | "services"

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
        radius: Style.panelRadius
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
            labelA: "Appearance"
            labelB: "Services"
            selected: root._tab === "services" ? 1 : 0
            onToggled: (i) => root._tab = (i === 0 ? "appearance" : "services")
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
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    RowLayout {
                        spacing: 6
                        StatusDot { active: settingsProcess && settingsProcess.googleConnected }
                        ColumnLayout {
                            spacing: 1
                            Text {
                                text: (settingsProcess && settingsProcess.googleConnected)
                                    ? "Connected" : "Not connected"
                                color: Style.textNormal
                                font.family: Style.fontMono
                                font.pixelSize: Style.fontSizeBody
                            }
                            Text {
                                visible: settingsProcess
                                    && settingsProcess.googleConnected
                                    && settingsProcess.googleEmail !== ""
                                text: settingsProcess ? settingsProcess.googleEmail : ""
                                color: Style.textMuted
                                font.family: Style.fontMono
                                font.pixelSize: Style.fontSizeSubtle
                            }
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
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
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
                            radius: Style.panelElementRadius
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
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

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
                        ScrollChip {
                            text: Prefs.fontSizePill + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.fontSizePill + delta
                                if (next >= 10 && next <= 24) Prefs.setFontSizePill(next)
                            }
                        }
                    }

                    PanelDivider {}

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
                        ScrollChip {
                            text: Prefs.fontSizeBase + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.fontSizeBase + delta
                                if (next >= 8 && next <= 18) Prefs.setFontSizeBase(next)
                            }
                        }
                    }

                    PanelDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Vis. clock"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        ScrollChip {
                            text: Prefs.fontSizeVisClock + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.fontSizeVisClock + delta * 4
                                if (next >= 40 && next <= 200) Prefs.setFontSizeVisClock(next)
                            }
                        }
                    }

                    PanelDivider {}

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
                        FontPicker {
                            Layout.fillWidth: true
                            value: Prefs.fontMono
                            onCommitted: (f) => Prefs.setFontMono(f)
                        }
                    }

                    PanelDivider {}

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
                        FontPicker {
                            Layout.fillWidth: true
                            value: Prefs.fontNerd
                            onCommitted: (f) => Prefs.setFontNerd(f)
                        }
                    }

                    PanelDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Vis. clock"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        FontPicker {
                            Layout.fillWidth: true
                            value: Prefs.fontVisClock
                            onCommitted: (f) => Prefs.setFontVisClock(f)
                        }
                    }
                }
            }

            // Padding
            Text {
                text: "Padding"
                color: Style.textPrimary
                font.family: Style.fontMono
                font.pixelSize: Style.fontSizeHeading
                font.bold: true
            }

            PanelCard {
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Pill"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        ScrollChip {
                            text: Prefs.pillPaddingV + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.pillPaddingV + delta
                                if (next >= 4 && next <= 50) Prefs.setPillPaddingV(next)
                            }
                        }
                    }

                    PanelDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Panel"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        ScrollChip {
                            text: Prefs.panelCardPadding + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.panelCardPadding + delta
                                if (next >= 4 && next <= 32) Prefs.setPanelCardPadding(next)
                            }
                        }
                    }

                    PanelDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Elements"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        ScrollChip {
                            text: Prefs.panelElementPadding + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.panelElementPadding + delta
                                if (next >= 8 && next <= 40) Prefs.setPanelElementPadding(next)
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
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Pill"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        ScrollChip {
                            text: Prefs.pillRadius + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.pillRadius + delta
                                if (next >= 0 && next <= 50) Prefs.setPillRadius(next)
                            }
                        }
                    }

                    PanelDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Panel"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        ScrollChip {
                            text: Prefs.panelRadius + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.panelRadius + delta
                                if (next >= 0 && next <= 30) Prefs.setPanelRadius(next)
                            }
                        }
                    }

                    PanelDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Elements"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        ScrollChip {
                            text: Prefs.panelElementRadius + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.panelElementRadius + delta
                                if (next >= 0 && next <= 12) Prefs.setPanelElementRadius(next)
                            }
                        }
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
                Layout.fillWidth: true
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Pill"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        ScrollChip {
                            text: Prefs.pillBorderWidth + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.pillBorderWidth + delta
                                if (next >= 0 && next <= 4) Prefs.setPillBorderWidth(next)
                            }
                        }
                    }

                    PanelDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Panel"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        ScrollChip {
                            text: Prefs.borderWidth + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.borderWidth + delta
                                if (next >= 0 && next <= 4) Prefs.setBorderWidth(next)
                            }
                        }
                    }

                    PanelDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Elements"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        ScrollChip {
                            text: Prefs.elementBorderWidth + "px"
                            onScrolled: (delta) => {
                                var next = Prefs.elementBorderWidth + delta
                                if (next >= 0 && next <= 4) Prefs.setElementBorderWidth(next)
                            }
                        }
                    }

                    PanelDivider {}

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: "Color"
                            color: Style.textSecondary
                            font.family: Style.fontMono
                            font.pixelSize: Style.fontSizeBody
                            Layout.minimumWidth: 80
                        }
                        Item { Layout.fillWidth: true }
                        PanelButton {
                            label: "Subtle"
                            variant: Prefs.borderColorMode === "subtle" ? "accent" : "default"
                            onClicked: Prefs.setBorderColorMode("subtle")
                        }
                        PanelButton {
                            label: "Vibrant"
                            variant: Prefs.borderColorMode === "vibrant" ? "accent" : "default"
                            onClicked: Prefs.setBorderColorMode("vibrant")
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
                Layout.fillWidth: true
                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
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
                        onClicked: Prefs.setExtractColors(!Prefs.extractColors)
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
                    Prefs.setFontVisClock("JetBrainsMono Nerd Font")
                    Prefs.setFontSizeVisClock(100)
                    Prefs.setFontSizePill(13)
                    Prefs.setFontSizeBase(10)
                    Prefs.setPillRadius(10)
                    Prefs.setPanelRadius(10)
                    Prefs.setPanelElementRadius(4)
                    Prefs.setPillBorderWidth(1)
                    Prefs.setPillPaddingV(20)
                    Prefs.setPanelCardPadding(12)
                    Prefs.setPanelElementPadding(20)
                    Prefs.setBorderWidth(1)
                    Prefs.setElementBorderWidth(1)
                    Prefs.setBorderColorMode("subtle")
                    Prefs.setExtractColors(false)
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
