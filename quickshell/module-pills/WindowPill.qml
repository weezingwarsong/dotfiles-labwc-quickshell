import QtQuick

Item {
    id: root

    // Injected by shell.qml
    property var  toplevelProcess: null
    // Externally controlled — true while window switcher panel is open
    property bool shouldShow: false

    // ── Priority interface (read by PillController) ───────────────────────────
    readonly property int  priority:     shouldShow ? 200 : 0
    readonly property bool shouldReveal: shouldShow

    readonly property string _appId: {
        if (toplevelProcess && toplevelProcess.focused)
            return toplevelProcess.focused.appId
        return ""
    }

    property Component visualComponent: Component {
        Row {
            height: parent.height
            spacing: 6

            Text {
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: root._glyphFor(root._appId)
                color: Style.accentColor
                font.family: Style.fontNerd
                font.pixelSize: Style.fontSizePill
            }

            Text {
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                width: Math.min(implicitWidth, 200)
                text: root._appId
                color: Style.textPrimary
                font.pixelSize: Style.fontSizePill
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

    onShouldShowChanged: console.log("[WindowPill] shouldShow:", shouldShow, "| app:", _appId)
    Component.onCompleted: console.log("[WindowPill] started")
}
