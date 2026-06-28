import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property bool hovered: false

    implicitWidth: parent ? parent.width : 0
    readonly property int calendarGap: Math.round(Screen.height * 0.01)
    implicitHeight: hovered ? clockBox.height + calendarGap + calendarWidget.implicitHeight : clockBox.height

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
        color: Style.rectMainBg
        border.width: Style.rectBorderWidth
        border.color: Style.rectMainBorder
        width: parent.width
        height: 24

        Text {
            id: clock
            anchors.centerIn: parent
            text: Qt.formatTime(new Date(), "HHmm")
            color: Style.textHeaderHighlight
            font.family: Style.fontFamily
            font.pointSize: Style.fontSize
        }
    }

    Rectangle {
        id: calendarWidget
        anchors.top: clockBox.bottom
        anchors.topMargin: root.calendarGap
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        color: Style.rectNormalBg
        border.width: Style.rectBorderWidth
        border.color: Style.rectNormalBorder
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
                    color: Style.textBodyHighlight
                    font.family: Style.fontFamily
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
                    color: today ? Style.textBodyHighlight
                         : month === monthGrid.month ? Style.textBodyNormal
                         : Style.textBodyLow
                    font.family: Style.fontFamily
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
