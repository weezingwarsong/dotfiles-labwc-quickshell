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
        height: localHovered ? 26 : Style.pillHeight
        color: root.saved ? Style.pillBg : Style.pillCriticalBg
        border.width: Style.borderWidth
        border.color: root.saved ? Style.pillBorder : Style.pillCriticalBorder
        radius: height / 2
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Style.nord0
            shadowBlur: container.localHovered ? 0.55 : 0.25
            shadowVerticalOffset: container.localHovered ? 6 : 2
            shadowOpacity: container.localHovered ? 0.8 : 0.5
        }

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
