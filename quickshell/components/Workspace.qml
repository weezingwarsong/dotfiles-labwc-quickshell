import QtQuick

Item {
    id: root

    property string workspace: "1"

    readonly property int squareSize: 14

    implicitWidth: box.width
    implicitHeight: box.height

    Rectangle {
        id: box
        color: "#3B4252"
        width: parent.width
        height: 24

        Row {
            anchors.centerIn: parent
            spacing: 3

            Rectangle {
                width: root.squareSize
                height: root.squareSize
                color: root.workspace === "1" ? "#8FBCBB" : "#4C566A"
            }

            Rectangle {
                width: root.squareSize
                height: root.squareSize
                color: root.workspace === "2" ? "#8FBCBB" : "#4C566A"
            }
        }
    }
}
