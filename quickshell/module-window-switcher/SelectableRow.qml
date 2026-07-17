import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string glyph:      ""
    property string label1:     ""
    property string label2:     ""
    property bool   isSelected: false
    property bool   isActive:   false

    signal activated()
    signal hovered()

    Layout.fillWidth: true
    implicitHeight:   _rowLayout.implicitHeight + Style.panelElementVpadding

    Rectangle {
        anchors.fill: parent
        radius: Style.panelElementRadius
        color: root.isSelected ? Style.accentBgColor
             : _tap.active     ? Style.surfaceHoverColor
             : _hover.hovered  ? Style.surfaceLowColor
             :                   Style.transparent
    }

    HoverHandler {
        id: _hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered) root.hovered()
    }

    TapHandler {
        id: _tap
        onTapped: root.activated()
    }

    RowLayout {
        id: _rowLayout
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Style.panelElementHpadding

        Text {
            text:                root.glyph
            color:               root.isSelected ? Style.textPrimary
                               : root.isActive   ? Style.textAccent
                               :                   Style.textMuted
            font.family:         Style.fontNerd
            font.pixelSize:      Style.fontSizeBody
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: Math.round(root.width * 0.10)
        }

        ScrollingText {
            text:           root.label1
            color:          root.isSelected ? Style.textPrimary
                          : root.isActive   ? Style.textSecondary
                          :                   Style.textNormal
            font.family:    Style.fontMono
            font.pixelSize: Style.fontSizeBody
            Layout.fillWidth:      root.label2 === ""
            Layout.preferredWidth: root.label2 !== "" ? Math.round(root.width * 0.25) : -1
        }

        ScrollingText {
            text:           root.label2
            color:          root.isSelected ? Style.textSecondary
                          :                   Style.textMuted
            font.family:    Style.fontMono
            font.pixelSize: Style.fontSizeBody
            visible:        root.label2 !== ""
            Layout.fillWidth: true
        }
    }
}
