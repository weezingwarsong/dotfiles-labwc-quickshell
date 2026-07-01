import QtQuick

Item {
    id: root

    property bool hovered: false  // unused; present so every Pill shares the same interface

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Style.pillHeight

    Text {
        anchors.centerIn: parent
        text: "Window"
        color: Style.textPillHighlight
        font.family: Style.fontFamily
        font.pointSize: Style.fontSize
    }
}
