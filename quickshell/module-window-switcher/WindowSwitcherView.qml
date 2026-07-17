import QtQuick
import QtQuick.Layouts
import Quickshell

FocusScope {
    id: root

    property var toplevelProcess: null

    signal dismissed()

    implicitHeight: Style.panelCardVpadding + _filterBar.height + Style.panelCardVpadding + _list.implicitHeight + Style.panelCardVpadding

    Component.onCompleted: Qt.callLater(function() { filterInput.forceActiveFocus() })

    // ── Filtered lists ─────────────────────────────────────────────────────

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

    // ── Filter bar ─────────────────────────────────────────────────────────

    Rectangle {
        id: _filterBar
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Style.panelCardVpadding }
        height:       Style.fontSizeHeading + Style.panelElementHpadding
        color:        Style.surfaceMidColor
        radius:       Style.panelElementRadius
        border.width: Style.elementBorderWidth
        border.color: Style.borderSoftColor

        Text {
            anchors { left: parent.left; right: parent.right; leftMargin: Style.panelElementHpadding; verticalCenter: parent.verticalCenter }
            text:           "Filter…"
            color:          Style.textMuted
            font.family:    Style.fontMono
            font.pixelSize: Style.fontSizeHeading
            visible:        filterInput.text.length === 0
        }

        TextInput {
            id: filterInput
            anchors { left: parent.left; right: parent.right; leftMargin: Style.panelElementHpadding; rightMargin: Style.panelElementHpadding; verticalCenter: parent.verticalCenter }
            focus:          true
            color:          Style.accentColor
            font.family:    Style.fontMono
            font.pixelSize: Style.fontSizeHeading
            selectionColor: Style.accentBgColor

            onTextChanged: root.selectedFlat = 0

            Keys.priority: Keys.BeforeItem
            Keys.onUpPressed: (e) => {
                if (root.selectedFlat > 0) root.selectedFlat--
                e.accepted = true
            }
            Keys.onDownPressed: (e) => {
                var total = root.filteredWindows.length + root.filteredApps.length
                if (root.selectedFlat < total - 1) root.selectedFlat++
                e.accepted = true
            }
            Keys.onReturnPressed: (e) => { root._activateSelected(); e.accepted = true }
            Keys.onEscapePressed: (e) => { root.dismissed(); e.accepted = true }
        }
    }

    // ── Scrollable list ────────────────────────────────────────────────────

    Flickable {
        anchors {
            left: parent.left; right: parent.right
            leftMargin: Style.panelCardVpadding; rightMargin: Style.panelCardVpadding
            top: _filterBar.bottom; topMargin: Style.panelCardVpadding
            bottom: parent.bottom; bottomMargin: Style.panelCardVpadding
        }
        contentHeight: _list.implicitHeight
        clip:          true

        ColumnLayout {
            id: _list
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: Style.panelCardVpadding

            // ── Windows section ───────────────────────────────────────────

            PanelCard {
                Layout.fillWidth: true
                SectionLabel {
                    text: "Windows"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.panelElementVpadding

                    Repeater {
                        model: root.filteredWindows
                        delegate: SelectableRow {
                            required property var modelData
                            required property int index

                            glyph:      root._glyphFor(modelData.appId)
                            label1:     modelData.appId
                            label2:     modelData.title
                            isSelected: root.selectedFlat === index
                            isActive:   modelData.activated

                            onHovered:   root.selectedFlat = index
                            onActivated: { modelData.activate(); root.dismissed() }
                        }
                    }
                }
            }

            // ── App Launcher section ──────────────────────────────────────

            PanelCard {
                Layout.fillWidth: true
                visible: root.filteredApps.length > 0

                SectionLabel {
                    text: "App Launcher"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.panelElementVpadding

                    Repeater {
                        model: root.filteredApps
                        delegate: SelectableRow {
                            required property var modelData
                            required property int index

                            glyph:      root._glyphFor(modelData.id ?? "")
                            label1:     modelData.name || ""
                            label2:     ""
                            isSelected: root.selectedFlat === (root.filteredWindows.length + index)
                            isActive:   false

                            onHovered:   root.selectedFlat = root.filteredWindows.length + index
                            onActivated: { modelData.execute(); root.dismissed() }
                        }
                    }
                }
            }
        }
    }
}
