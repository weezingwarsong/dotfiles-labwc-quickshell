import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Panel-only: the pill row itself lives in TimePill.qml, rolled by the
// shared bar in shell.qml.  This component is just the expanded calendar
// panel, anchored directly below the bar; `hovered` is fed in externally
// from TimePill's own hover state (shell.qml wires the two together).
Item {
    id: root

    property bool hovered: false

    implicitWidth: parent ? parent.width : 0
    readonly property int calendarGap: Math.round(Screen.height * 0.01)
    implicitHeight: hovered ? calendarGap + calendarWidget.implicitHeight : 0

    Rectangle {
        id: calendarWidget
        anchors.top: parent.top
        anchors.topMargin: root.calendarGap
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        color: Style.panelBg
        border.width: Style.borderWidth
        border.color: Style.panelBorder
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
                    color: Style.textPanelHighlight
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
                    color: today ? Style.textPanelHighlight
                         : month === monthGrid.month ? Style.textPanelNormal
                         : Style.textPanelLow
                    font.family: Style.fontFamily
                    font.pointSize: 11
                    font.bold: today
                }
            }
        }
    }
}
