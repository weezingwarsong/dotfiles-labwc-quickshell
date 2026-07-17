import QtQuick
import QtQuick.Layouts
import Quickshell

FocusScope {
    id: root

    // Injected by WindowSwitcher
    property var toplevelProcess: null

    signal dismissed()

    implicitHeight: _col.implicitHeight

    Component.onCompleted: Qt.callLater(function() { filterInput.forceActiveFocus() })

    // ── Filtered lists ────────────────────────────────────────────────────────

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

    readonly property var filteredApps: {
        var q = filterInput.text.toLowerCase()
        if (!q) return []
        var src = DesktopEntries.applications
        var apps = (src && src.values !== undefined) ? src.values : src
        if (!apps) return []
        var result = []
        for (var i = 0; i < apps.length; i++) {
            var a = apps[i]
            if (!a || a.noDisplay) continue
            if ((a.name || "").toLowerCase().indexOf(q) >= 0)
                result.push(a)
        }
        return result
    }

    function _activateSelected() {
        var i = root.selectedFlat
        if (i < root.filteredWindows.length) {
            if (i >= 0) {
                root.filteredWindows[i].activate()
                root.dismissed()
            }
        } else {
            var ai = i - root.filteredWindows.length
            if (ai >= 0 && ai < root.filteredApps.length) {
                root.filteredApps[ai].execute()
                root.dismissed()
            }
        }
    }

    function _glyphFor(appId) {
        var id = (appId || "").toLowerCase()
        if (id === "kitty" || id === "alacritty" || id === "foot" ||
            id === "wezterm" || id === "xterm" || id === "konsole" ||
            id === "gnome-terminal" || id === "xfce4-terminal")
            return String.fromCodePoint(0xf489)
        if (id === "firefox" || id === "librewolf" ||
            id === "org.mozilla.firefox")
            return String.fromCodePoint(0xf269)
        if (id === "google-chrome" || id === "chromium" ||
            id === "chromium-browser" || id === "microsoft-edge" ||
            id === "brave-browser" || id === "brave")
            return String.fromCodePoint(0xf268)
        if (id === "pcmanfm-qt" || id === "pcmanfm" ||
            id === "thunar" || id === "nautilus" ||
            id === "dolphin" || id === "nemo")
            return String.fromCodePoint(0xf07b)
        if (id === "code" || id === "vscodium" || id === "codium")
            return String.fromCodePoint(0xe70c)
        if (id === "nvim" || id === "neovim")
            return String.fromCodePoint(0xe7c5)
        if (id === "discord")
            return String.fromCodePoint(0xf392)
        if (id === "steam" || id.indexOf("steam_app") === 0)
            return String.fromCodePoint(0xf1b6)
        if (id === "qbittorrent")
            return String.fromCodePoint(0xf019)
        if (id === "vlc" || id === "org.videolan.vlc" ||
            id === "celluloid" || id === "mpv")
            return String.fromCodePoint(0xf144)
        if (id === "imv" || id === "imv-wayland" || id === "eog")
            return String.fromCodePoint(0xf03e)
        if (id === "pavucontrol-qt" || id === "pavucontrol")
            return String.fromCodePoint(0xf028)
        if (id === "btop")
            return String.fromCodePoint(0xf080)
        return String.fromCodePoint(0xf2d0)
    }

    // ── Layout ────────────────────────────────────────────────────────────────

    ColumnLayout {
        id: _col
        anchors.fill:    parent
        anchors.margins: 8
        spacing:         4

        // ── Filter bar ────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight:   Style.buttonHeight
            color:            Style.surfaceMidColor
            radius:           Style.panelElementRadius
            border.width:     Style.elementBorderWidth
            border.color:     Style.borderSoftColor

            Text {
                anchors { fill: parent; leftMargin: 8 }
                verticalAlignment: Text.AlignVCenter
                text:           "Filter…"
                color:          Style.textMuted
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeBody
                visible:        filterInput.text.length === 0
            }

            TextInput {
                id: filterInput
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                verticalAlignment: TextInput.AlignVCenter
                focus:          true
                color:          Style.textPrimary
                font.family:    Style.fontMono
                font.pixelSize: Style.fontSizeBody
                selectionColor: Style.accentBgColor

                onTextChanged: root.selectedFlat = 0

                Keys.priority: Keys.BeforeItem
                Keys.onUpPressed:   (e) => { if (root.selectedFlat > 0) root.selectedFlat--; e.accepted = true }
                Keys.onDownPressed: (e) => {
                    var total = root.filteredWindows.length + root.filteredApps.length
                    if (root.selectedFlat < total - 1) root.selectedFlat++
                    e.accepted = true
                }
                Keys.onReturnPressed: (e) => { root._activateSelected(); e.accepted = true }
                Keys.onEscapePressed: (e) => { root.dismissed(); e.accepted = true }
            }
        }

        // ── Scrollable list ───────────────────────────────────────────────────
        Flickable {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            contentHeight:     _list.implicitHeight
            clip:              true

            ColumnLayout {
                id: _list
                anchors { left: parent.left; right: parent.right; top: parent.top }
                spacing: 0

                // ── Window rows ───────────────────────────────────────────────
                Repeater {
                    model: root.filteredWindows
                    delegate: Item {
                        id: winItem
                        required property var modelData
                        required property int index

                        property bool isHovered:   false
                        readonly property bool isActivated: modelData.activated
                        readonly property bool isSelected:  root.selectedFlat === index

                        Layout.fillWidth: true
                        implicitHeight:   Style.buttonHeight

                        Rectangle {
                            anchors.fill: parent
                            color: winItem.isSelected ? Style.accentBgColor
                                 : winItem.isHovered  ? Style.surfaceLowColor
                                 :                      Style.transparent
                        }

                        HoverHandler {
                            onHoveredChanged: {
                                winItem.isHovered = hovered
                                if (hovered) root.selectedFlat = winItem.index
                            }
                        }
                        TapHandler {
                            onTapped: { winItem.modelData.activate(); root.dismissed() }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            spacing: 6

                            Text {
                                text:                root._glyphFor(winItem.modelData.appId)
                                color:               winItem.isSelected  ? Style.textPrimary
                                                  : winItem.isActivated  ? Style.textAccent
                                                  :                        Style.textMuted
                                font.family:         Style.fontNerd
                                font.pixelSize:      Style.fontSizeBody
                                horizontalAlignment: Text.AlignHCenter
                                Layout.preferredWidth: 18
                            }

                            Text {
                                text:                winItem.modelData.appId
                                color:               winItem.isSelected  ? Style.textPrimary
                                                  : winItem.isActivated  ? Style.textSecondary
                                                  :                        Style.textNormal
                                font.family:         Style.fontMono
                                font.pixelSize:      Style.fontSizeBody
                                elide:               Text.ElideRight
                                Layout.preferredWidth: Math.round(_list.width * 0.25)
                            }

                            Text {
                                text:           winItem.modelData.title
                                color:          winItem.isSelected  ? Style.textSecondary
                                             : winItem.isActivated  ? Style.textMuted
                                             :                        Style.textMuted
                                font.family:    Style.fontMono
                                font.pixelSize: Style.fontSizeBody
                                elide:          Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // ── Divider ───────────────────────────────────────────────────
                PanelDivider { visible: root.filteredApps.length > 0 }

                // ── Desktop app rows ──────────────────────────────────────────
                Repeater {
                    model: root.filteredApps
                    delegate: Item {
                        id: appItem
                        required property var modelData
                        required property int index

                        property bool isHovered:  false
                        readonly property bool isSelected:
                            root.selectedFlat === (root.filteredWindows.length + index)

                        Layout.fillWidth: true
                        implicitHeight:   Style.buttonHeight

                        Rectangle {
                            anchors.fill: parent
                            color: appItem.isSelected ? Style.accentBgColor
                                 : appItem.isHovered  ? Style.surfaceLowColor
                                 :                      Style.transparent
                        }

                        HoverHandler {
                            onHoveredChanged: {
                                appItem.isHovered = hovered
                                if (hovered) root.selectedFlat = root.filteredWindows.length + appItem.index
                            }
                        }
                        TapHandler {
                            onTapped: { appItem.modelData.execute(); root.dismissed() }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            spacing: 6

                            Text {
                                text:                root._glyphFor(appItem.modelData.id ?? "")
                                color:               appItem.isSelected ? Style.textPrimary : Style.textMuted
                                font.family:         Style.fontNerd
                                font.pixelSize:      Style.fontSizeBody
                                horizontalAlignment: Text.AlignHCenter
                                Layout.preferredWidth: 18
                            }

                            Text {
                                text:           appItem.modelData.name || ""
                                color:          appItem.isSelected ? Style.textPrimary : Style.textNormal
                                font.family:    Style.fontMono
                                font.pixelSize: Style.fontSizeBody
                                elide:          Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
