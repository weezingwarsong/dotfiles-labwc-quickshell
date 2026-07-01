import QtQuick

Item {
    id: root

    property string workspace:     "1"
    property var    workspaceList: []

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

            Repeater {
                model: root.workspaceList
                Rectangle {
                    width: root.squareSize
                    height: root.squareSize
                    color: modelData === root.workspace ? Style.textPillHighlight : Style.textPillLow
                }
            }
        }
    }
}
