import QtQuick

Item {
    id: root

    // Injected by shell.qml
    property var toplevelProcess: null
    // Externally controlled — true while window switcher panel is open
    property bool shouldShow: false

    readonly property string _appId: {
        if (toplevelProcess && toplevelProcess.focused)
            return toplevelProcess.focused.appId
        return ""
    }

    property Component visualComponent: Component {
        Row {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root._glyphFor(root._appId)
                color: Style.textPrimary
                font.family: Style.fontNerd
                font.pixelSize: Style.pillTextSize
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root._appId
                color: Style.textPrimary
                font.pixelSize: Style.pillTextSize
                font.family: Style.fontMono
                elide: Text.ElideRight
                visible: root._appId.length > 0
            }
        }
    }

    function _glyphFor(appId) {
        var id = appId.toLowerCase()
        if (id === "kitty" || id === "alacritty" || id === "foot" ||
            id === "wezterm" || id === "xterm" || id === "konsole" ||
            id === "gnome-terminal" || id === "xfce4-terminal")   return ""
        if (id === "firefox" || id === "librewolf" ||
            id === "org.mozilla.firefox")                          return ""
        if (id === "google-chrome" || id === "chromium" ||
            id === "chromium-browser" || id === "microsoft-edge" ||
            id === "brave-browser" || id === "brave")             return ""
        if (id === "pcmanfm-qt" || id === "pcmanfm" ||
            id === "thunar" || id === "nautilus" ||
            id === "dolphin" || id === "nemo")                    return ""
        if (id === "code" || id === "vscodium" || id === "codium") return ""
        if (id === "nvim" || id === "neovim")                     return ""
        if (id === "discord")                                      return ""
        if (id === "steam" || id.indexOf("steam_app") === 0)      return ""
        if (id === "qbittorrent")                                  return ""
        if (id === "vlc" || id === "org.videolan.vlc" ||
            id === "celluloid" || id === "mpv")                   return ""
        if (id === "imv" || id === "imv-wayland" || id === "eog") return ""
        if (id === "pavucontrol-qt" || id === "pavucontrol")      return ""
        if (id === "btop")                                         return ""
        return ""
    }

    onShouldShowChanged: console.log("[WindowPill] shouldShow:", shouldShow, "| app:", _appId)
    Component.onCompleted: console.log("[WindowPill] started")
}
