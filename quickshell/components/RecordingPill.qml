import QtQuick

Item {
    id: root
    property bool saved: false
    property bool hovered: false  // unused; present so every Pill shares the same interface

    implicitWidth: parent ? parent.width : label.implicitWidth + 12
    implicitHeight: Style.pillHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: root.saved ? "RECORDING SAVED" : "RECORDING"
        color: root.saved ? Style.textSuccess : Style.textBright
        font.family: Style.fontFamily
        font.pointSize: Style.fontSize
        font.weight: Font.Bold
    }
}
