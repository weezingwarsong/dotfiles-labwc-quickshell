import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool hovered: false

    implicitWidth: parent ? parent.width : calendarWidget.width
    implicitHeight: hovered ? clockBox.height + calendarWidget.implicitHeight : clockBox.height

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited: root.hovered = false
    }

    Rectangle {
        id: clockBox
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#3B4252"
        width: parent.width
        height: 24

        Text {
            id: clock
            anchors.centerIn: parent
            text: Qt.formatTime(new Date(), "HHmm")
            color: "#8FBCBB"
            font.family: "JetBrainsMono Nerd Font"
            font.pointSize: 10
        }
    }

    Rectangle {
        id: calendarWidget
        anchors.top: clockBox.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 260
        opacity: 0.9
        color: "#3B4252"
        implicitHeight: calendarLayout.implicitHeight + 16

        ColumnLayout {
            id: calendarLayout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }
            spacing: 4

            DayOfWeekRow {
                Layout.fillWidth: true

                delegate: Text {
                    required property string shortName
                    text: shortName
                    horizontalAlignment: Text.AlignHCenter
                    color: "#8FBCBB"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pointSize: 11
                }
            }

            MonthGrid {
                id: monthGrid
                Layout.fillWidth: true
                month: new Date().getMonth()
                year: new Date().getFullYear()

                delegate: Text {
                    required property int day
                    required property int month
                    required property bool today

                    text: day
                    horizontalAlignment: Text.AlignHCenter
                    leftPadding: 3
                    rightPadding: 3
                    color: today ? "#8FBCBB"
                         : month === monthGrid.month ? "#D8DEE9"
                         : "#4C566A"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pointSize: 11
                    font.bold: today
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.text = Qt.formatTime(new Date(), "HHmm")
    }
}
