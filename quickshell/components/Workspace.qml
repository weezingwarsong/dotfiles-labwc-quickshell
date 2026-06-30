import QtQuick

Item {
    id: root

    property string workspace: "1"

    readonly property int squareSize: 14

    implicitWidth: box.width
    implicitHeight: box.height

    Rectangle {
        id: box
        color: Style.pillBg
        border.width: Style.borderWidth
        border.color: Style.pillBorder
        radius: height / 2
        width: parent.width
        height: Style.pillHeight

        Row {
            anchors.centerIn: parent
            spacing: 3

            Rectangle {
                width: root.squareSize
                height: root.squareSize
                color: root.workspace === "1" ? Style.textPillHighlight : Style.textPillLow
            }

            Rectangle {
                width: root.squareSize
                height: root.squareSize
                color: root.workspace === "2" ? Style.textPillHighlight : Style.textPillLow
            }
        }
    }
}
