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
    radius: Style.panelButtonRadius
    border.width: Style.panelButtonBorderWidth
    border.color: Style.panelButtonBorder
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Style.panelButtonShadowColor
        shadowBlur: root.localHovered ? Style.panelButtonShadowBlurHover : Style.panelButtonShadowBlurRest
        shadowVerticalOffset: root.localHovered ? Style.panelButtonShadowVerticalOffsetHover : Style.panelButtonShadowVerticalOffsetRest
        shadowOpacity: root.localHovered ? Style.panelButtonShadowOpacityHover : Style.panelButtonShadowOpacityRest
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
