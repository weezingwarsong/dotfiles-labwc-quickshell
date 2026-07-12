import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 4

    property string activePanel: ""

    readonly property var _order:  ["calendar", "mediaPlayer", "settings", "wallpaper", "notifications", "control"]
    readonly property var _titles: ({
        "calendar":      "Calendar",
        "mediaPlayer":   "Media Player",
        "settings":      "Settings",
        "wallpaper":     "Wallpapers",
        "notifications": "Notifications",
        "control":       "Controls"
    })
    readonly property int _activeIndex: _order.indexOf(activePanel)

    signal navigateRequested(int direction)

    Text {
        Layout.fillWidth: true
        text:                root._titles[root.activePanel] || ""
        color:               Style.accentColor
        font.family:         Style.fontMono
        font.pixelSize:      Style.fontSizeHeading
        horizontalAlignment: Text.AlignHCenter
    }

    RowLayout {
        Layout.fillWidth: true

        IconButton { label: "‹"; onClicked: root.navigateRequested(-1) }

        Item { Layout.fillWidth: true }

        Row {
            spacing: 4
            Repeater {
                model: root._order.length
                Text {
                    text:  index === root._activeIndex
                           ? String.fromCodePoint(0xf444)
                           : String.fromCodePoint(0xf4c3)
                    color: index === root._activeIndex ? Style.accentColor : Style.textFaint
                    font.family:    Style.fontNerd
                    font.pixelSize: Style.fontSizeBody
                }
            }
        }

        Item { Layout.fillWidth: true }

        IconButton { label: "›"; onClicked: root.navigateRequested(+1) }
    }
}
