import QtQuick
import QtQuick.Controls as QQC

Item {
    id: root
    property string text: ""
    property string tooltip: ""
    property bool collapsed: false

    signal toggled()

    implicitHeight: 22
    implicitWidth: _row.implicitWidth

    Row {
        id: _row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            text: root.collapsed ? "▸" : "▾"
            color: Style.textMuted
            font.family: Style.fontMono
            font.pixelSize: Style.fontSizeBody
        }

        Text {
            text: root.text
            color: _hover.hovered ? Style.textNormal : Style.textPrimary
            font.family: Style.fontMono
            font.pixelSize: Style.fontSizeHeading
            font.bold: true
        }
    }

    HoverHandler { id: _hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.toggled() }

    QQC.ToolTip {
        visible: _hover.hovered && root.tooltip !== ""
        text: root.tooltip
        delay: 500
    }
}
