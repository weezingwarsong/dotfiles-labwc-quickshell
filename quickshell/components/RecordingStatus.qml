import QtQuick

Item {
    id: root
    property bool saved: false

    implicitWidth: container.implicitWidth
    implicitHeight: container.implicitHeight

    Rectangle {
        id: container
        implicitWidth: label.implicitWidth + 12
        implicitHeight: 24
        color: "#3B4252"

        Text {
            id: label
            anchors.centerIn: parent
            text: root.saved ? "RECORDING SAVED" : "RECORDING"
            color: root.saved ? "#A3BE8C" : "#BF616A"
            font.family: "JetBrainsMono Nerd Font"
            font.pointSize: 10
            font.weight: Font.Bold
        }
    }
}
