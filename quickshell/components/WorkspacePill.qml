import QtQuick

Item {
    id: root

    property string workspace:     "1"
    property var    workspaceList: []
    property bool   hovered: false  // unused; present so every Pill shares the same interface

    readonly property int squareSize: 14

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Style.pillHeight

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
