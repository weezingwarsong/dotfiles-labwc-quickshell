import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property int padding: 12

    Layout.fillWidth: true
    // Height driven by child content — callers place a ColumnLayout at y: parent.padding
    implicitHeight: childrenRect.y + childrenRect.height + padding

    color:        Style.surfaceLowColor
    radius:       Style.radLg
    border.width: Style.borderWidth
    border.color: Style.borderFaintColor
}
