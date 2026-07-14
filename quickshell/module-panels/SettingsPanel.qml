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

    // ── Local state ───────────────────────────────────────────────────────────
    property string _locationDraft: settingsProcess ? settingsProcess.locationString : ""
    property bool   _revoking:      false
    property string _tab:           "appearance"

    // ── Collapse state (appearance tab) ───────────────────────────────────────
    property bool _typographyCollapsed: false
    property bool _paddingCollapsed:    false
    property bool _cornerCollapsed:     false
    property bool _bordersCollapsed:    false
    property bool _themeCollapsed:      false

    // ── Filter ────────────────────────────────────────────────────────────────
    property string _filter: ""

    readonly property var _tagTypography: ["pill text","panel text","vis clock","font size","mono font","glyph font","typography","font"]
    readonly property var _tagPadding:    ["pill","panel","elements","padding","spacing","margin"]
    readonly property var _tagCorner:     ["pill","panel","elements","radius","round","corner","rounding"]
    readonly property var _tagBorders:    ["pill","panel","elements","border","color","subtle","vibrant","thickness","width"]
    readonly property var _tagTheme:      ["extract","colors","wallpaper","theme","palette"]

    function _matches(name, tags) {
        if (_filter === "") return true
        var q = _filter.toLowerCase()
        if (name.toLowerCase().indexOf(q) >= 0) return true
        for (var i = 0; i < tags.length; i++) {
            if (tags[i].toLowerCase().indexOf(q) >= 0) return true
        }
        return false
    }

    // Visibility shortcuts for appearance sections
    readonly property bool _typoVisible:   _matches("Typography",      _tagTypography)
    readonly property bool _paddingVisible: _matches("Padding",        _tagPadding)
    readonly property bool _cornerVisible:  _matches("Corner rounding", _tagCorner)
    readonly property bool _bordersVisible: _matches("Borders",         _tagBorders)
    readonly property bool _themeVisible:   _matches("Theme",           _tagTheme)

    // ── Height ────────────────────────────────────────────────────────────────
    // Reports full content height so PanelSurface can cap. Flickable scrolls
    // within whatever height PanelSurface actually assigns.
    implicitHeight: _pinnedCol.implicitHeight + 12 +
        (_tab === "services" ? _servicesLayout.implicitHeight : _appearanceLayout.implicitHeight) +
        24

    // ── Key handler (type-to-filter) ──────────────────────────────────────────
    // Left/Right are never consumed — they propagate to PanelSurface for nav.
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (_filter !== "") {
                _filter = ""
                _flickable.contentY = 0
                event.accepted = true
            }
            return
        }
        if (event.key === Qt.Key_Backspace) {
            if (_filter !== "") {
                _filter = _filter.slice(0, -1)
                _flickable.contentY = 0
                event.accepted = true
            }
            return
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
            event.key === Qt.Key_Up   || event.key === Qt.Key_Down  ||
            event.key === Qt.Key_Tab  || event.key === Qt.Key_Return) return
        if (event.text.length > 0) {
            _filter += event.text
            _flickable.contentY = 0
            event.accepted = true
        }
    }

    // ── Processes ─────────────────────────────────────────────────────────────
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

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Style.panelRadius
        color: Style.panelBgColor
        border.color: Style.panelBorderColor
        border.width: Style.borderWidth
        clip: true
    }

    // ── Pinned header ─────────────────────────────────────────────────────────
    ColumnLayout {
        id: _pinnedCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 12

        PanelNavBar {
            activePanel: root.activePanel
            onNavigateRequested: (dir) => root.navigateRequested(dir)
        }

        TogglePair {
            labelA: "Appearance"
            labelB: "Services"
            selected: root._tab === "services" ? 1 : 0
            onToggled: (i) => {
                root._tab = (i === 0 ? "appearance" : "services")
                root._filter = ""
                _flickable.contentY = 0
            }
        }

        // Filter bar — appears when _filter is non-empty
        Rectangle {
            visible: _filter !== ""
            Layout.fillWidth: true
            implicitHeight: Style.buttonHeight
            radius: Style.panelElementRadius
            color: Style.surfaceMidColor
            border.width: Style.elementBorderWidth
            border.color: Style.borderSoftColor

            Row {
                anchors {
                    left: parent.left; right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 8; rightMargin: 8
                }
                spacing: 4

                Text {
                    text: "⌕"
                    color: Style.textMuted
                    font.family: Style.fontMono
                    font.pixelSize: Style.fontSizeBody
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: _filter
                    color: Style.textNormal
                    font.family: Style.fontMono
                    font.pixelSize: Style.fontSizeBody
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "│"
                    color: Style.accentColor
                    font.family: Style.fontMono
                    font.pixelSize: Style.fontSizeBody
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }
            }
        }
    }

    // ── Scrollable content ────────────────────────────────────────────────────
    Flickable {
        id: _flickable
        anchors {
            left: parent.left;   leftMargin:   12
            right: parent.right; rightMargin:  12
            top: _pinnedCol.bottom; topMargin: 12
            bottom: parent.bottom;  bottomMargin: 12
        }
        contentWidth: width
        contentHeight: _tab === "services"
            ? _servicesLayout.implicitHeight
            : _appearanceLayout.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

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

        // ── Services tab ──────────────────────────────────────────────────────
        ColumnLayout {
            id: _servicesLayout
            visible: _tab === "services"
            width: parent.width
            spacing: 12

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
            id: _appearanceLayout
            visible: _tab === "appearance"
            width: parent.width
            spacing: 8

            // ── Typography ────────────────────────────────────────────────────
            SectionHeader {
                Layout.fillWidth: true
                text: "Typography"
                tooltip: "Font sizes and families"
                collapsed: _typographyCollapsed
                visible: _typoVisible
                onToggled: _typographyCollapsed = !_typographyCollapsed
            }
            PanelCard {
                Layout.fillWidth: true
                visible: _typoVisible && (_filter !== "" || !_typographyCollapsed)
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

            // ── Padding ───────────────────────────────────────────────────────
            SectionHeader {
                Layout.fillWidth: true
                text: "Padding"
                tooltip: "Spacing inside cards and elements"
                collapsed: _paddingCollapsed
                visible: _paddingVisible
                onToggled: _paddingCollapsed = !_paddingCollapsed
            }
            PanelCard {
                Layout.fillWidth: true
                visible: _paddingVisible && (_filter !== "" || !_paddingCollapsed)
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

            // ── Corner rounding ───────────────────────────────────────────────
            SectionHeader {
                Layout.fillWidth: true
                text: "Corner rounding"
                tooltip: "Border radius for pill, panels, and elements"
                collapsed: _cornerCollapsed
                visible: _cornerVisible
                onToggled: _cornerCollapsed = !_cornerCollapsed
            }
            PanelCard {
                Layout.fillWidth: true
                visible: _cornerVisible && (_filter !== "" || !_cornerCollapsed)
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

            // ── Borders ───────────────────────────────────────────────────────
            SectionHeader {
                Layout.fillWidth: true
                text: "Borders"
                tooltip: "Border thickness and color"
                collapsed: _bordersCollapsed
                visible: _bordersVisible
                onToggled: _bordersCollapsed = !_bordersCollapsed
            }
            PanelCard {
                Layout.fillWidth: true
                visible: _bordersVisible && (_filter !== "" || !_bordersCollapsed)
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

            // ── Theme ─────────────────────────────────────────────────────────
            SectionHeader {
                Layout.fillWidth: true
                text: "Theme"
                tooltip: "Wallpaper color extraction"
                collapsed: _themeCollapsed
                visible: _themeVisible
                onToggled: _themeCollapsed = !_themeCollapsed
            }
            PanelCard {
                Layout.fillWidth: true
                visible: _themeVisible && (_filter !== "" || !_themeCollapsed)
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

            // ── Reset ─────────────────────────────────────────────────────────
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
    }

    function _applyLocation() {
        if (settingsProcess && _locationDraft.trim() !== "")
            settingsProcess.setLocationString(_locationDraft.trim())
    }
}
