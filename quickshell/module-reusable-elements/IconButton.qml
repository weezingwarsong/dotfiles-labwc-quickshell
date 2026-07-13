import QtQuick

Rectangle {
    id: root

    property string label:      ""
    property string fontFamily: Style.fontNerd  // Nerd Font covers regular text + glyph codepoints
    signal clicked()

    implicitWidth:  Style.buttonHeight
    implicitHeight: Style.buttonHeight
    radius:         Style.panelElementRadius
    border.width:   Style.elementBorderWidth
    border.color:   Style.borderSoftColor
    color:          _hover.hovered ? Style.surfaceLowColor : Style.transparent

    Text {
        anchors.centerIn: parent
        text:           root.label
        font.family:    root.fontFamily
        font.pixelSize: Style.fontSizeBody
        color:          Style.textSecondary
    }

    HoverHandler { id: _hover; cursorShape: Qt.PointingHandCursor }
    TapHandler   { onTapped: root.clicked() }
}
