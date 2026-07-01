import QtQuick
import Quickshell.Io

// Panel-only: the pill row itself lives in WindowPill.qml, rolled by the
// shared bar in shell.qml.  This component is just the expanded switch
// panel, anchored directly below the bar.
FocusScope {
    id: root

    property var windows: []   // [{app_id, title, states}]
    property int selectedFlat: 0

    signal windowFocused()

    readonly property int _gap: Math.round(Screen.height * 0.01)

    readonly property var filteredWindows: {
        var result = []
        for (var i = 0; i < windows.length; i++) {
            var w = windows[i]
            if (filterInput.text === "" ||
                    (w.app_id + " " + w.title).toLowerCase()
                        .indexOf(filterInput.text.toLowerCase()) >= 0)
                result.push(w)
        }
        return result
    }

    readonly property int totalSelectable: filteredWindows.length

    implicitWidth: parent ? parent.width : 0
    implicitHeight: _gap + switchPanel.implicitHeight

    Component.onCompleted: Qt.callLater(function() { filterInput.forceActiveFocus() })

    function _glyphFor(appId) {
        var id = appId.toLowerCase()
        if (id === "kitty" || id === "alacritty" || id === "foot" ||
            id === "wezterm" || id === "xterm" || id === "konsole" ||
            id === "gnome-terminal" || id === "xfce4-terminal")  return ""  // terminal
        if (id === "firefox" || id === "librewolf" ||
            id === "org.mozilla.firefox")                         return ""  // firefox
        if (id === "google-chrome" || id === "chromium" ||
            id === "chromium-browser" || id === "microsoft-edge" ||
            id === "microsoft-edge-dev" || id === "brave-browser" ||
            id === "brave")                                       return ""  // chrome
        if (id === "pcmanfm-qt" || id === "pcmanfm" || id === "thunar" ||
            id === "nautilus" || id === "dolphin" || id === "nemo") return "" // folder
        if (id === "code" || id === "vscodium" || id === "codium") return "" // vscode
        if (id === "nvim" || id === "neovim")                    return ""  // vim
        if (id === "discord")                                    return ""  // discord
        if (id === "steam" || id.indexOf("steam_app") === 0)    return ""  // steam
        if (id === "qbittorrent")                                return ""  // download
        if (id === "vlc" || id === "org.videolan.vlc" ||
            id === "celluloid" || id === "mpv")                  return ""  // play
        if (id === "imv" || id === "imv-wayland" || id === "eog") return "" // picture
        if (id === "pavucontrol-qt" || id === "pavucontrol")    return ""  // volume
        if (id === "btop")                                       return ""  // chart
        return ""  // window-maximize fallback
    }

    function focusSelected() {
        if (selectedFlat >= 0 && selectedFlat < filteredWindows.length)
            _doFocus(filteredWindows[selectedFlat])
    }

    function _doFocus(w) {
        focusProcess.command = ["wlrctl", "toplevel", "focus",
                                "app_id:" + w.app_id, "title:" + w.title]
        focusProcess.running = true
        root.windowFocused()
    }

    // ── Switch panel ────────────────────────────────────────────────────────
    Rectangle {
        id: switchPanel
        anchors.top: parent.top; anchors.topMargin: root._gap
        width: parent.width
        color: Style.panelBg
        border.width: Style.borderWidth; border.color: Style.panelBorder
        implicitHeight: col.implicitHeight + 16

        Column {
            id: col
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                topMargin: 8; leftMargin: 8; rightMargin: 8
            }
            spacing: 4

            // Filter input
            Rectangle {
                width: parent.width; height: 28
                color: Style.panelButtonBg
                border.width: Style.borderWidth; border.color: Style.panelButtonBorder

                Text {
                    anchors.fill: parent; anchors.leftMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: "Filter…"
                    color: Style.textPanelLow
                    font.family: Style.fontFamily; font.pointSize: Style.fontSize
                    visible: filterInput.text.length === 0
                }

                TextInput {
                    id: filterInput
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true
                    color: Style.textPanelNormal
                    font.family: Style.fontFamily; font.pointSize: Style.fontSize
                    selectionColor: Style.textPanelHighlight

                    onTextChanged: root.selectedFlat = 0

                    Keys.priority: Keys.BeforeItem
                    Keys.onUpPressed:     function(event) { if (root.selectedFlat > 0) root.selectedFlat--; event.accepted = true }
                    Keys.onDownPressed:   function(event) { if (root.selectedFlat < root.totalSelectable - 1) root.selectedFlat++; event.accepted = true }
                    Keys.onReturnPressed: function(event) { root.focusSelected(); event.accepted = true }
                }
            }

            // ── Window list ────────────────────────────────────────────────
            Repeater {
                model: root.filteredWindows
                Rectangle {
                    id: winItem
                    required property var modelData   // {app_id, title, states}
                    required property int index
                    property bool isHovered: false
                    readonly property bool isActive: modelData.states && modelData.states.activated
                    readonly property bool isSelected: root.selectedFlat === index

                    width: col.width; height: 22
                    color: isSelected ? Style.textPanelHighlight
                         : isHovered  ? Style.panelButtonBg
                         :              "transparent"

                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true
                        onEntered: { parent.isHovered = true; root.selectedFlat = parent.index }
                        onExited:  parent.isHovered = false
                        onClicked: root._doFocus(parent.modelData)
                    }

                    Text {
                        id: glyphCol
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 6
                        width: 18
                        horizontalAlignment: Text.AlignHCenter
                        renderType: Text.NativeRendering
                        text: root._glyphFor(winItem.modelData.app_id)
                        color: isSelected ? Style.textPanelGlyphOnHighlight : isActive ? Style.textPanelLow : Style.textPanelGlyphNormal
                        font.family: Style.fontFamily; font.pointSize: Style.fontSize
                    }

                    Text {
                        id: appNameCol
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: glyphCol.right; anchors.leftMargin: 6
                        width: Math.round(parent.width * 0.25)
                        text: winItem.modelData.app_id
                        color: isSelected ? Style.textPanelOnHighlight : isActive ? Style.textPanelLow : Style.textPanelNormal
                        font.family: Style.fontFamily; font.pointSize: Style.fontSize
                        elide: Text.ElideRight
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: appNameCol.right; anchors.leftMargin: 6
                        anchors.right: parent.right; anchors.rightMargin: 6
                        text: winItem.modelData.title
                        color: isSelected ? Style.textPanelOnHighlight : isActive ? Style.textPanelLow : Style.textPanelNormal
                        font.family: Style.fontFamily; font.pointSize: Style.fontSize
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Process {
        id: focusProcess
    }
}
