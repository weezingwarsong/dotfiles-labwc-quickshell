import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell.Widgets
import Quickshell.Services.SystemTray

Item {
    id: root

    // Repeater.count is always a valid reactive int — avoids SystemTray.items.count
    // which is undefined on the underlying Quickshell model type.
    readonly property int count: _rep.count

    implicitWidth:  _row.implicitWidth
    implicitHeight: _row.implicitHeight
    clip:           true

    RowLayout {
        id: _row
        anchors.fill: parent
        spacing: 4

        Repeater {
            id: _rep
            model: SystemTray.items

            delegate: Rectangle {
                id: _btn
                required property var modelData

                width:  24
                height: 24
                radius: Style.radSm
                color:  _hov.hovered ? Style.surfaceMidColor : "transparent"

                IconImage {
                    anchors.centerIn: parent
                    width:  18
                    height: 18
                    source: _btn.modelData.icon
                }

                HoverHandler { id: _hov; cursorShape: Qt.PointingHandCursor }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: _btn.modelData.activate()
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: _btn.modelData.secondaryActivate()
                }

                QQC.ToolTip {
                    visible: _hov.hovered && (_btn.modelData.title || "") !== ""
                    text:    _btn.modelData.title || ""
                    delay:   500
                }
            }
        }
    }
}
