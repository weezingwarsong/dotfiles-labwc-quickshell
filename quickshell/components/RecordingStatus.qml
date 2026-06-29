import QtQuick
import QtQuick.Effects

Item {
    id: root
    property bool saved: false

    implicitWidth: parent ? parent.width : label.implicitWidth + 12
    implicitHeight: 24

    Rectangle {
        id: container
        property bool localHovered: false
        x: localHovered ? -2 : 0
        width: localHovered ? parent.width + 4 : parent.width
        height: localHovered ? 26 : 24
        color: root.saved ? Style.rectMainBg : Style.rectMainCriticalBg
        border.width: Style.rectBorderWidth
        border.color: root.saved ? Style.rectMainBorder : Style.rectMainCriticalBorder
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Style.nord0
            shadowBlur: container.localHovered ? 0.55 : 0.25
            shadowVerticalOffset: container.localHovered ? 6 : 2
            shadowOpacity: container.localHovered ? 0.8 : 0.5
            Behavior on shadowBlur { NumberAnimation { duration: 120 } }
            Behavior on shadowVerticalOffset { NumberAnimation { duration: 120 } }
            Behavior on shadowOpacity { NumberAnimation { duration: 120 } }
        }
        Behavior on x { NumberAnimation { duration: 80 } }
        Behavior on width { NumberAnimation { duration: 80 } }
        Behavior on height { NumberAnimation { duration: 80 } }

        HoverHandler { onHoveredChanged: container.localHovered = hovered }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.saved ? "RECORDING SAVED" : "RECORDING"
            color: root.saved ? Style.textSuccess : Style.textBright
            font.family: Style.fontFamily
            font.pointSize: Style.fontSize
            font.weight: Font.Bold
        }
    }
}
