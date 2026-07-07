import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string labelA:  ""
    property string labelB:  ""
    property int    selected: 0

    signal toggled(int index)

    implicitHeight: Style.buttonHeight
    Layout.fillWidth: true

    // Outer border + selection highlights
    Rectangle {
        anchors.fill: parent
        color:        Style.transparent
        radius:       Style.radSm
        border.width: Style.elementBorderWidth
        border.color: Style.borderSoftColor

        // Left selection highlight (per-corner radius — Qt 6.7+)
        Rectangle {
            visible:          root.selected === 0
            x: 1; y: 1
            width:            parent.width / 2 - 1
            height:           parent.height - 2
            color:            Style.accentBgColor
            topLeftRadius:    Style.radSm
            bottomLeftRadius: Style.radSm
        }

        // Right selection highlight
        Rectangle {
            visible:           root.selected === 1
            x:                 parent.width / 2
            y:                 1
            width:             parent.width / 2 - 1
            height:            parent.height - 2
            color:             Style.accentBgColor
            topRightRadius:    Style.radSm
            bottomRightRadius: Style.radSm
        }

        // Centre divider
        Rectangle {
            x:      parent.width / 2 - Math.floor(Style.elementBorderWidth / 2)
            y:      1
            width:  Style.elementBorderWidth
            height: parent.height - 2
            color:  Style.borderSoftColor
        }
    }

    // Labels
    Row {
        anchors.fill: parent

        Text {
            width:               parent.width / 2
            height:              parent.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
            text:                root.labelA
            font.family:         Style.fontMono
            font.pixelSize:      Style.fontSizeBody
            color:               root.selected === 0 ? Style.textMuted : Style.textSecondary
        }

        Text {
            width:               parent.width / 2
            height:              parent.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
            text:                root.labelB
            font.family:         Style.fontMono
            font.pixelSize:      Style.fontSizeBody
            color:               root.selected === 1 ? Style.textMuted : Style.textSecondary
        }
    }

    // Click zones
    Row {
        anchors.fill: parent

        Item {
            width:  parent.width / 2
            height: parent.height
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler   { onTapped: if (root.selected !== 0) root.toggled(0) }
        }

        Item {
            width:  parent.width / 2
            height: parent.height
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler   { onTapped: if (root.selected !== 1) root.toggled(1) }
        }
    }
}
