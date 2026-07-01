import QtQuick

Item {
    id: root
    property bool hovered: false

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Style.pillHeight

    HoverHandler {
        onHoveredChanged: root.hovered = hovered
    }

    Text {
        id: clock
        anchors.centerIn: parent
        text: Qt.formatTime(new Date(), "HHmm")
        color: Style.textPillHighlight
        font.family: Style.fontFamily
        font.pointSize: Style.fontSize
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.text = Qt.formatTime(new Date(), "HHmm")
    }
}
