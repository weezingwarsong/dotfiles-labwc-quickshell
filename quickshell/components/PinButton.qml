import QtQuick
import QtQuick.Effects

// Small square button shown once a hover-panel becomes permanent (pinned).
// Click unpins it. Panels reserve a constant-height row for this so pinning
// doesn't resize them — only this button's own visibility toggles within it.
// Styled like every other Button in a panel (focus button, filter input):
// panelButton colors, hover-grow, drop shadow.
Rectangle {
    id: root
    signal clicked()

    property bool localHovered: false

    anchors.right: parent ? parent.right : undefined
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: localHovered ? 26 : 22
    height: localHovered ? 26 : 22
    color: Style.panelButtonBg
    border.width: Style.borderWidth
    border.color: Style.panelButtonBorder
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Style.nord0
        shadowBlur: root.localHovered ? 0.55 : 0.25
        shadowVerticalOffset: root.localHovered ? 6 : 2
        shadowOpacity: root.localHovered ? 0.8 : 0.5
    }

    HoverHandler { onHoveredChanged: root.localHovered = hovered }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Text {
        anchors.centerIn: parent
        text: String.fromCharCode(0xf08d)  // thumbtack
        color: Style.textPanelHighlight
        font.family: Style.fontFamily
        font.pointSize: Style.fontSize
    }
}
