import QtQuick

Rectangle {
    id: root

    property string label: ""
    signal clicked()

    implicitWidth:  Style.buttonHeight
    implicitHeight: Style.buttonHeight
    radius:         Style.radSm
    border.width:   Style.elementBorderWidth
    border.color:   Style.borderSoftColor
    color:          _hover.hovered ? Style.surfaceLowColor : Style.transparent

    Text {
        anchors.centerIn: parent
        text:           root.label
        font.family:    Style.fontMono
        font.pixelSize: Style.fontSizeBody
        color:          Style.textSecondary
    }

    HoverHandler { id: _hover; cursorShape: Qt.PointingHandCursor }
    TapHandler   { onTapped: root.clicked() }
}
