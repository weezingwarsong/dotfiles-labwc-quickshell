import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Panel-only: the pill row itself lives in TimePill.qml, rolled by the
// shared bar in shell.qml.  This component is just the expanded calendar
// panel, anchored directly below the bar. `hovered` and `pinned` are fed in
// externally from shell.qml's root-level combined-region hover/pin state
// (not local to this instance, since it gets destroyed/recreated whenever
// another module briefly takes over the bar).
Item {
    id: root

    property bool hovered: false
    property bool pinned: false

    signal dismissRequested()

    implicitWidth: parent ? parent.width : 0
    readonly property int calendarGap: Math.round(Screen.height * 0.01)
    implicitHeight: (hovered || pinned) ? calendarGap + calendarWidget.implicitHeight : 0

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

            // Always reserved so pinning doesn't resize the panel — only the
            // button's own visibility toggles within this constant-height row.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                PinButton {
                    visible: root.pinned
                    onClicked: root.dismissRequested()
                }
            }

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
