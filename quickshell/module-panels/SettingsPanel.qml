import QtQuick
import QtQuick.Layouts
import Quickshell.Io

FocusScope {
    id: root

    // ── Injected processes ────────────────────────────────────────────────────
    property var    settingsProcess:  null
    property var    calendarProcess:  null
    property var    tasksProcess:     null
    property var    wallpaperProcess: null
    // ── Local state ───────────────────────────────────────────────────────────
    property string _locationDraft: settingsProcess ? settingsProcess.locationString : ""
    property bool   _revoking:      false
    property string _tab:           "appearance"

    // ── Collapse state ────────────────────────────────────────────────────────
    property bool _googleCollapsed:     false
    property bool _weatherCollapsed:    false
    property bool _typographyCollapsed: false
    property bool _paddingCollapsed:    false
    property bool _cornerCollapsed:     false
    property bool _bordersCollapsed:    false
    property bool _themeCollapsed:      false
    property bool _wallpaperCollapsed:  false
    property bool _panelCollapsed:      false

    // ── Filter ────────────────────────────────────────────────────────────────
    property string _filter: ""

    readonly property var _tagTypography: ["pill text","panel text","vis clock","font size","mono font","glyph font","typography","font"]
    readonly property var _tagPadding:    ["pill","panel","elements","padding","spacing","margin"]
    readonly property var _tagCorner:     ["pill","panel","elements","radius","round","corner","rounding"]
    readonly property var _tagBorders:    ["pill","panel","elements","border","color","subtle","vibrant","thickness","width"]
    readonly property var _tagTheme:      ["extract","colors","wallpaper","theme","palette"]
    readonly property var _tagWallpaper:  ["wallpaper","directory","scan","path","image","video","folder","pictures"]
    readonly property var _tagPanel:      ["panel","width","height","offset","position","size","layout"]

    function _matches(name, tags) {
        if (_filter === "") return true
        var q = _filter.toLowerCase()
        if (name.toLowerCase().indexOf(q) >= 0) return true
        for (var i = 0; i < tags.length; i++) {
            if (tags[i].toLowerCase().indexOf(q) >= 0) return true
        }
        return false
    }

    readonly property bool _typoVisible:     _matches("Typography",      _tagTypography)
    readonly property bool _paddingVisible:  _matches("Padding",        _tagPadding)
    readonly property bool _cornerVisible:   _matches("Corner rounding", _tagCorner)
    readonly property bool _bordersVisible:  _matches("Borders",         _tagBorders)
    readonly property bool _themeVisible:    _matches("Theme",           _tagTheme)
    readonly property bool _wallpaperVisible: _matches("Wallpaper",      _tagWallpaper)
    readonly property bool _panelVisible:    _matches("Panel",           _tagPanel)

    // ── Height ────────────────────────────────────────────────────────────────
    implicitHeight: _pinnedCol.implicitHeight + 12 +
        (_tab === "services" ? _servicesLayout.implicitHeight : _appearanceLayout.implicitHeight)

    // Tab toggles between Appearance and Services — intercepted here before bubbling to Loader.
    Keys.onTabPressed: (event) => {
        root._tab = (root._tab === "appearance" ? "services" : "appearance")
        _filterInput.text = ""
        _flickable.contentY = 0
        event.accepted = true
    }

    // ── Filter input (invisible key sink) ────────────────────────────────────
    TextInput {
        id: _filterInput
        width: 0; height: 0
        focus: true
        color: "transparent"
        selectionColor: "transparent"

        Component.onCompleted: Qt.callLater(function() { _filterInput.forceActiveFocus() })

        Keys.onLeftPressed:  (e) => e.accepted = false
        Keys.onRightPressed: (e) => e.accepted = false
        Keys.onUpPressed:    (e) => e.accepted = false
        Keys.onDownPressed:  (e) => e.accepted = false
        Keys.onReturnPressed: (e) => e.accepted = false
        Keys.onTabPressed:    (e) => e.accepted = false

        onTextChanged: {
            _filter = text
            _flickable.contentY = 0
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

    // ── Pinned header ─────────────────────────────────────────────────────────
    ColumnLayout {
        id: _pinnedCol
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: 12

        PanelTabBar {
            labels:   ["Appearance", "Services"]
            selected: root._tab === "services" ? 1 : 0
            onToggled: (i) => {
                root._tab = (i === 0 ? "appearance" : "services")
                _filterInput.text = ""
                _flickable.contentY = 0
            }
        }

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
                Text { text: "⌕"; color: Style.textMuted; font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody; anchors.verticalCenter: parent.verticalCenter }
                Text { text: _filterInput.text; color: Style.textNormal; font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "│"; color: Style.accentColor; font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody; anchors.verticalCenter: parent.verticalCenter
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
            left: parent.left
            right: parent.right
            top: _pinnedCol.bottom; topMargin: 12
            bottom: parent.bottom
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
            spacing: 8

            // Google Account card
            PanelCard {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "Google Account"
                        tooltip: "Calendar and Tasks integration"
                        collapsed: _googleCollapsed
                        onToggled: _googleCollapsed = !_googleCollapsed
                    }

                    Item {
                        Layout.fillWidth: true
                        clip: true
                        Layout.preferredHeight: !_googleCollapsed ? _googleRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _googleRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            spacing: 8

                            RowLayout {
                                spacing: 6
                                StatusDot { active: settingsProcess && settingsProcess.googleConnected }
                                ColumnLayout {
                                    spacing: 1
                                    Text {
                                        text: (settingsProcess && settingsProcess.googleConnected) ? "Connected" : "Not connected"
                                        color: Style.textNormal; font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody
                                    }
                                    Text {
                                        visible: settingsProcess && settingsProcess.googleConnected && settingsProcess.googleEmail !== ""
                                        text: settingsProcess ? settingsProcess.googleEmail : ""
                                        color: Style.textMuted; font.family: Style.fontMono; font.pixelSize: Style.fontSizeSubtle
                                    }
                                }
                            }

                            ColumnLayout {
                                visible: settingsProcess && settingsProcess.googleConnected
                                Layout.fillWidth: true
                                spacing: 4

                                RowLayout {
                                    spacing: 8
                                    Text { text: "Calendar"; color: Style.textSecondary; font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody; Layout.minimumWidth: 60 }
                                    Text { text: root._calendarStatus(); color: root._calendarStatusColor(); font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody }
                                }
                                RowLayout {
                                    spacing: 8
                                    Text { text: "Tasks"; color: Style.textSecondary; font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody; Layout.minimumWidth: 60 }
                                    Text { text: root._tasksStatus(); color: root._tasksStatusColor(); font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                PanelButton {
                                    label: (settingsProcess && settingsProcess.googleConnected) ? "Re-authenticate" : "Connect"
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
                                    onClicked: { if (!root._revoking) { root._revoking = true; revokeProcess.running = true } }
                                }
                            }
                        }
                    }
                }
            }

            // Weather Location card
            PanelCard {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "Weather Location"
                        tooltip: "Location used for weather data"
                        collapsed: _weatherCollapsed
                        onToggled: _weatherCollapsed = !_weatherCollapsed
                    }

                    Item {
                        Layout.fillWidth: true
                        clip: true
                        Layout.preferredHeight: !_weatherCollapsed ? _weatherRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _weatherRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
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
                                        color: Style.textNormal; font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody
                                        selectByMouse: true; clip: true

                                        Text {
                                            visible: !parent.text && !parent.activeFocus
                                            anchors.fill: parent
                                            text: "City name or lat,lon"
                                            color: Style.textMuted; font.family: Style.fontMono; font.pixelSize: Style.fontSizeBody
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onTextChanged: root._locationDraft = text
                                        onAccepted: _applyLocation()
                                    }
                                }

                                PanelButton { label: "Apply"; onClicked: _applyLocation() }
                            }
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
            PanelCard {
                Layout.fillWidth: true
                visible: _typoVisible
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "Typography"; tooltip: "Font sizes and families"
                        collapsed: _typographyCollapsed
                        onToggled: _typographyCollapsed = !_typographyCollapsed
                    }

                    Item {
                        Layout.fillWidth: true; clip: true
                        Layout.preferredHeight: (_filter !== "" || !_typographyCollapsed) ? _typoRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _typoRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            spacing: 8

                            RowLabel { label: "Pill text"
                                ScrollChip { text: Prefs.fontSizePill + "px"; onScrolled: (delta) => { var next = Prefs.fontSizePill + delta; if (next >= 10 && next <= 24) Prefs.setFontSizePill(next) } }
                            }
                            PanelDivider {}
                            RowLabel { label: "Panel text"
                                ScrollChip { text: Prefs.fontSizeBase + "px"; onScrolled: (delta) => { var next = Prefs.fontSizeBase + delta; if (next >= 8 && next <= 18) Prefs.setFontSizeBase(next) } }
                            }
                            PanelDivider {}
                            RowLabel { label: "Vis. clock"
                                ScrollChip { text: Prefs.fontSizeVisClock + "px"; onScrolled: (delta) => { var next = Prefs.fontSizeVisClock + delta * 4; if (next >= 40 && next <= 200) Prefs.setFontSizeVisClock(next) } }
                            }
                            PanelDivider {}
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                RowLabel { label: "Mono font" }
                                FontPicker {
                                    Layout.preferredWidth: parent.width * 0.6
                                    value: Prefs.fontMono
                                    onCommitted: (f) => Prefs.setFontMono(f)
                                }
                            }
                            PanelDivider {}
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                RowLabel { label: "Glyph font" }
                                FontPicker {
                                    Layout.preferredWidth: parent.width * 0.6
                                    value: Prefs.fontNerd
                                    onCommitted: (f) => Prefs.setFontNerd(f)
                                }
                            }
                            PanelDivider {}
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                RowLabel { label: "Vis. clock" }
                                FontPicker {
                                    Layout.preferredWidth: parent.width * 0.6
                                    value: Prefs.fontVisClock
                                    onCommitted: (f) => Prefs.setFontVisClock(f)
                                }
                            }
                        }
                    }
                }
            }

            // ── Padding ───────────────────────────────────────────────────────
            PanelCard {
                Layout.fillWidth: true
                visible: _paddingVisible
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "Padding"; tooltip: "Spacing inside cards and elements"
                        collapsed: _paddingCollapsed
                        onToggled: _paddingCollapsed = !_paddingCollapsed
                    }

                    Item {
                        Layout.fillWidth: true; clip: true
                        Layout.preferredHeight: (_filter !== "" || !_paddingCollapsed) ? _paddingRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _paddingRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            spacing: 8

                            RowLabel { label: "Pill"
                                ScrollChip { text: Prefs.pillPaddingV + "px"; onScrolled: (delta) => { var next = Prefs.pillPaddingV + delta; if (next >= 4 && next <= 50) Prefs.setPillPaddingV(next) } }
                            }
                            PanelDivider {}
                            RowLabel { label: "Panel"
                                ScrollChip { text: Prefs.panelCardPadding + "px"; onScrolled: (delta) => { var next = Prefs.panelCardPadding + delta; if (next >= 4 && next <= 32) Prefs.setPanelCardPadding(next) } }
                            }
                            PanelDivider {}
                            RowLabel { label: "Elements"
                                ScrollChip { text: Prefs.panelElementPadding + "px"; onScrolled: (delta) => { var next = Prefs.panelElementPadding + delta; if (next >= 8 && next <= 40) Prefs.setPanelElementPadding(next) } }
                            }
                        }
                    }
                }
            }

            // ── Corner rounding ───────────────────────────────────────────────
            PanelCard {
                Layout.fillWidth: true
                visible: _cornerVisible
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "Corner rounding"; tooltip: "Border radius for pill, panels, and elements"
                        collapsed: _cornerCollapsed
                        onToggled: _cornerCollapsed = !_cornerCollapsed
                    }

                    Item {
                        Layout.fillWidth: true; clip: true
                        Layout.preferredHeight: (_filter !== "" || !_cornerCollapsed) ? _cornerRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _cornerRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            spacing: 8

                            RowLabel { label: "Pill"
                                ScrollChip { text: Prefs.pillRadius + "px"; onScrolled: (delta) => { var next = Prefs.pillRadius + delta; if (next >= 0 && next <= 50) Prefs.setPillRadius(next) } }
                            }
                            PanelDivider {}
                            RowLabel { label: "Panel"
                                ScrollChip { text: Prefs.panelRadius + "px"; onScrolled: (delta) => { var next = Prefs.panelRadius + delta; if (next >= 0 && next <= 30) Prefs.setPanelRadius(next) } }
                            }
                            PanelDivider {}
                            RowLabel { label: "Elements"
                                ScrollChip { text: Prefs.panelElementRadius + "px"; onScrolled: (delta) => { var next = Prefs.panelElementRadius + delta; if (next >= 0 && next <= 12) Prefs.setPanelElementRadius(next) } }
                            }
                        }
                    }
                }
            }

            // ── Borders ───────────────────────────────────────────────────────
            PanelCard {
                Layout.fillWidth: true
                visible: _bordersVisible
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "Borders"; tooltip: "Border thickness and color"
                        collapsed: _bordersCollapsed
                        onToggled: _bordersCollapsed = !_bordersCollapsed
                    }

                    Item {
                        Layout.fillWidth: true; clip: true
                        Layout.preferredHeight: (_filter !== "" || !_bordersCollapsed) ? _bordersRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _bordersRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            spacing: 8

                            RowLabel { label: "Pill"
                                ScrollChip { text: Prefs.pillBorderWidth + "px"; onScrolled: (delta) => { var next = Prefs.pillBorderWidth + delta; if (next >= 0 && next <= 4) Prefs.setPillBorderWidth(next) } }
                            }
                            PanelDivider {}
                            RowLabel { label: "Panel"
                                ScrollChip { text: Prefs.borderWidth + "px"; onScrolled: (delta) => { var next = Prefs.borderWidth + delta; if (next >= 0 && next <= 4) Prefs.setBorderWidth(next) } }
                            }
                            PanelDivider {}
                            RowLabel { label: "Elements"
                                ScrollChip { text: Prefs.elementBorderWidth + "px"; onScrolled: (delta) => { var next = Prefs.elementBorderWidth + delta; if (next >= 0 && next <= 4) Prefs.setElementBorderWidth(next) } }
                            }
                            PanelDivider {}
                            RowLabel { label: "Color"
                                TogglePair {
                                    labelA: "Subtle"; labelB: "Vibrant"
                                    selected: Prefs.borderColorMode === "vibrant" ? 1 : 0
                                    onToggled: (i) => Prefs.setBorderColorMode(i === 0 ? "subtle" : "vibrant")
                                }
                            }
                        }
                    }
                }
            }

            // ── Panel ─────────────────────────────────────────────────────────
            PanelCard {
                Layout.fillWidth: true
                visible: _panelVisible
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "Panel"; tooltip: "Panel width and vertical position on screen"
                        collapsed: _panelCollapsed
                        onToggled: _panelCollapsed = !_panelCollapsed
                    }

                    Item {
                        Layout.fillWidth: true; clip: true
                        Layout.preferredHeight: (_filter !== "" || !_panelCollapsed) ? _panelRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _panelRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            spacing: 8

                            RowLabel { label: "Width"
                                ScrollChip { text: Prefs.panelWidth + "%"; onScrolled: (delta) => { var next = Prefs.panelWidth + delta; if (next >= 5 && next <= 50) Prefs.setPanelWidth(next) } }
                            }
                            PanelDivider {}
                            RowLabel { label: "Height"
                                ScrollChip { text: Prefs.panelOffsetY + "%"; onScrolled: (delta) => { var next = Prefs.panelOffsetY + delta; if (next >= 2 && next <= 25) Prefs.setPanelOffsetY(next) } }
                            }
                        }
                    }
                }
            }

            // ── Theme ─────────────────────────────────────────────────────────
            PanelCard {
                Layout.fillWidth: true
                visible: _themeVisible
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "Theme"; tooltip: "Wallpaper color extraction"
                        collapsed: _themeCollapsed
                        onToggled: _themeCollapsed = !_themeCollapsed
                    }

                    Item {
                        Layout.fillWidth: true; clip: true
                        Layout.preferredHeight: (_filter !== "" || !_themeCollapsed) ? _themeRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _themeRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }

                            RowLabel { label: "Extract colors"
                                TogglePair {
                                    labelA: "On"; labelB: "Off"; variant: "yesno"
                                    selected: Prefs.extractColors ? 0 : 1
                                    onToggled: (i) => Prefs.setExtractColors(i === 0)
                                }
                            }
                        }
                    }
                }
            }

            // ── Wallpaper ─────────────────────────────────────────────────────
            PanelCard {
                Layout.fillWidth: true
                visible: _wallpaperVisible
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text: "Wallpaper"; tooltip: "Directory scanned for images and videos"
                        collapsed: _wallpaperCollapsed
                        onToggled: _wallpaperCollapsed = !_wallpaperCollapsed
                    }

                    Item {
                        Layout.fillWidth: true; clip: true
                        Layout.preferredHeight: (_filter !== "" || !_wallpaperCollapsed) ? _wallpaperRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _wallpaperRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: Style.buttonHeight
                                    radius: Style.panelElementRadius
                                    color:  Style.surfaceMidColor
                                    border.width: Style.elementBorderWidth
                                    border.color: Style.borderSoftColor

                                    TextInput {
                                        id: _wallpaperDirInput
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 6 }
                                        text:           root.wallpaperProcess ? root.wallpaperProcess.wallpaperDir : ""
                                        color:          Style.textSecondary
                                        font.family:    Style.fontMono
                                        font.pixelSize: Style.fontSizeBody
                                        clip:           true
                                        selectByMouse:  true
                                        onAccepted: if (root.wallpaperProcess) root.wallpaperProcess.scanDirectory(text)

                                        Text {
                                            anchors.fill:   parent
                                            text:           "~/Pictures/wallpapers"
                                            color:          Style.textFaint
                                            font.family:    Style.fontMono
                                            font.pixelSize: Style.fontSizeBody
                                            visible:        _wallpaperDirInput.text === ""
                                        }
                                    }
                                }

                                PanelButton {
                                    label: "Scan"
                                    onClicked: if (root.wallpaperProcess) root.wallpaperProcess.scanDirectory(_wallpaperDirInput.text)
                                }
                            }
                        }
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
                    Prefs.setPanelWidth(15)
                    Prefs.setPanelOffsetY(10)
                }
            }
        }
    }

    function _applyLocation() {
        if (settingsProcess && _locationDraft.trim() !== "")
            settingsProcess.setLocationString(_locationDraft.trim())
    }
}
