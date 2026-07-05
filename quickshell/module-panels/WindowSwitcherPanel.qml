import QtQuick

FocusScope {
    id: root

    // Injected by PanelSurface
    property var toplevelProcess: null

    signal dismissed()

    // ── Window list with filter ───────────────────────────────────────────────

    property int selectedFlat: 0

    readonly property var filteredWindows: {
        var result = []
        if (!toplevelProcess) return result
        var tops = toplevelProcess.windows.values
        if (!tops) return result
        var q = filterInput.text.toLowerCase()
        for (var i = 0; i < tops.length; i++) {
            var t = tops[i]
            if (q === "" || (t.appId + " " + t.title).toLowerCase().indexOf(q) >= 0)
                result.push(t)
        }
        return result
    }

    Component.onCompleted: Qt.callLater(function() { filterInput.forceActiveFocus() })

    function _activateSelected() {
        if (selectedFlat >= 0 && selectedFlat < filteredWindows.length) {
            filteredWindows[selectedFlat].activate()
            root.dismissed()
        }
    }

    function _glyphFor(appId) {
        var id = appId.toLowerCase()
        if (id === "kitty" || id === "alacritty" || id === "foot" ||
            id === "wezterm" || id === "xterm" || id === "konsole" ||
            id === "gnome-terminal" || id === "xfce4-terminal")
            return String.fromCodePoint(0xf489)   // nf-fa-terminal
        if (id === "firefox" || id === "librewolf" ||
            id === "org.mozilla.firefox")
            return String.fromCodePoint(0xf269)   // nf-fa-firefox
        if (id === "google-chrome" || id === "chromium" ||
            id === "chromium-browser" || id === "microsoft-edge" ||
            id === "brave-browser" || id === "brave")
            return String.fromCodePoint(0xf268)   // nf-fa-chrome
        if (id === "pcmanfm-qt" || id === "pcmanfm" ||
            id === "thunar" || id === "nautilus" ||
            id === "dolphin" || id === "nemo")
            return String.fromCodePoint(0xf07b)   // nf-fa-folder
        if (id === "code" || id === "vscodium" || id === "codium")
            return String.fromCodePoint(0xe70c)   // nf-dev-visualstudio
        if (id === "nvim" || id === "neovim")
            return String.fromCodePoint(0xe7c5)   // nf-dev-vim
        if (id === "discord")
            return String.fromCodePoint(0xf392)   // nf-fa-discord
        if (id === "steam" || id.indexOf("steam_app") === 0)
            return String.fromCodePoint(0xf1b6)   // nf-fa-steam
        if (id === "qbittorrent")
            return String.fromCodePoint(0xf019)   // nf-fa-download
        if (id === "vlc" || id === "org.videolan.vlc" ||
            id === "celluloid" || id === "mpv")
            return String.fromCodePoint(0xf144)   // nf-fa-play_circle
        if (id === "imv" || id === "imv-wayland" || id === "eog")
            return String.fromCodePoint(0xf03e)   // nf-fa-picture_o
        if (id === "pavucontrol-qt" || id === "pavucontrol")
            return String.fromCodePoint(0xf028)   // nf-fa-volume_up
        if (id === "btop")
            return String.fromCodePoint(0xf080)   // nf-fa-bar_chart
        return String.fromCodePoint(0xf2d0)       // nf-fa-window_maximize
    }

    // ── Panel shell ───────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill: parent
        color: Style.panelBgColor
        radius: Style.panelBorderRadius
        border.width: Style.borderThin
        border.color: Style.panelBorderColor

        Column {
            id: col
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 8; leftMargin: 8; rightMargin: 8
            }
            spacing: 4

            // ── Filter bar ────────────────────────────────────────────────────
            Rectangle {
                width: parent.width
                height: 26
                color: Style.surfaceMidColor
                radius: Style.radButton
                border.width: Style.borderThin
                border.color: Style.borderSoftColor

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: "Filter…"
                    color: Style.textDim
                    font.family: Style.fontMono
                    font.pixelSize: Style.fontContentSize
                    visible: filterInput.text.length === 0
                }

                TextInput {
                    id: filterInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    color: Style.textPrimary
                    font.family: Style.fontMono
                    font.pixelSize: Style.fontContentSize
                    selectionColor: Style.accentBgColor

                    onTextChanged: root.selectedFlat = 0

                    Keys.priority: Keys.BeforeItem
                    Keys.onUpPressed: function(event) {
                        if (root.selectedFlat > 0) root.selectedFlat--
                        event.accepted = true
                    }
                    Keys.onDownPressed: function(event) {
                        if (root.selectedFlat < root.filteredWindows.length - 1)
                            root.selectedFlat++
                        event.accepted = true
                    }
                    Keys.onReturnPressed: function(event) {
                        root._activateSelected()
                        event.accepted = true
                    }
                    Keys.onEscapePressed: function(event) {
                        root.dismissed()
                        event.accepted = true
                    }
                }
            }

            // ── Window rows ───────────────────────────────────────────────────
            Repeater {
                model: root.filteredWindows
                delegate: Rectangle {
                    id: winItem
                    required property var modelData
                    required property int index

                    property bool isHovered: false
                    readonly property bool isActivated: modelData.activated
                    readonly property bool isSelected: root.selectedFlat === index

                    width: col.width
                    height: 22
                    color: isSelected   ? Style.accentBgColor
                         : isHovered    ? Style.surfaceLowColor
                         :               Style.transparent

                    HoverHandler {
                        onHoveredChanged: {
                            winItem.isHovered = hovered
                            if (hovered) root.selectedFlat = winItem.index
                        }
                    }

                    TapHandler {
                        onTapped: {
                            winItem.modelData.activate()
                            root.dismissed()
                        }
                    }

                    // Glyph
                    Text {
                        id: glyphCol
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        width: 18
                        horizontalAlignment: Text.AlignHCenter
                        text: root._glyphFor(winItem.modelData.appId)
                        color: winItem.isSelected  ? Style.textPrimary
                             : winItem.isActivated ? Style.textAccentColor
                             :                       Style.textMuted
                        font.family: Style.fontNerd
                        font.pixelSize: Style.fontContentSize
                    }

                    // App ID
                    Text {
                        id: appNameCol
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: glyphCol.right
                        anchors.leftMargin: 6
                        width: Math.round(parent.width * 0.25)
                        text: winItem.modelData.appId
                        color: winItem.isSelected  ? Style.textPrimary
                             : winItem.isActivated ? Style.textLight
                             :                       Style.textNormal
                        font.family: Style.fontMono
                        font.pixelSize: Style.fontContentSize
                        elide: Text.ElideRight
                    }

                    // Title
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: appNameCol.right
                        anchors.leftMargin: 6
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        text: winItem.modelData.title
                        color: winItem.isSelected  ? Style.textLight
                             : winItem.isActivated ? Style.textSubtle
                             :                       Style.textMuted
                        font.family: Style.fontMono
                        font.pixelSize: Style.fontContentSize
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
