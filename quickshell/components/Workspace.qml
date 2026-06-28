import QtQuick

Item {
    id: root

    property string workspace: "1"

    readonly property int squareSize: 14

    implicitWidth: box.width
    implicitHeight: box.height

    Rectangle {
        id: box
        color: Style.rectMainBg
        border.width: Style.rectBorderWidth
        border.color: Style.rectMainBorder
        width: parent.width
        height: 24

        Row {
            anchors.centerIn: parent
            spacing: 3

            Rectangle {
                width: root.squareSize
                height: root.squareSize
                color: root.workspace === "1" ? Style.textHeaderHighlight : Style.textHeaderLow
            }

            Rectangle {
                width: root.squareSize
                height: root.squareSize
                color: root.workspace === "2" ? Style.textHeaderHighlight : Style.textHeaderLow
            }
        }
    }
}
