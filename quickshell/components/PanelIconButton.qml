import QtQuick
import QtQuick.Effects

// Small square icon button for panel button rails (e.g. the calendar
// panel's settings / open-in-browser row). Same visual language as
// PinButton — hover-grow, drop shadow — but generic (icon + click signal)
// and sized by its parent Layout instead of self-anchoring.
//
// The outer Item's implicit size stays fixed at the max (hovered) size, so
// growing on hover doesn't change this item's footprint in the ColumnLayout
// and reflow its siblings — only the inner Rectangle grows/shrinks, centered
// within that fixed footprint. PinButton doesn't need this: it self-anchors
// outside any Layout, so resizing in place is safe there.
Item {
    id: root
    signal clicked()

    property string icon: ""
    property string tooltip: ""
    property bool localHovered: false

    implicitWidth: 30
    implicitHeight: 30

    PanelToolTip {
        visible: root.localHovered && root.tooltip !== ""
        text: root.tooltip
    }

    Rectangle {
        anchors.centerIn: parent
        width: root.localHovered ? 30 : 26
        height: root.localHovered ? 30 : 26
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
            text: root.icon
            color: Style.textPanelHighlight
            font.family: Style.fontFamily
            font.pointSize: Style.fontSize
        }
    }
}
