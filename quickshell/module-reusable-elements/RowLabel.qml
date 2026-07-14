import QtQuick
import QtQuick.Layouts

// Label + right-side control row. Two modes:
//   fill: false (default) — spacer pushes child to the right edge
//   fill: true            — no spacer; child should declare Layout.fillWidth: true
RowLayout {
    id: root

    property string label:      ""
    property int    labelWidth: 80
    property bool   fill:       false

    default property alias content: root.data

    Layout.fillWidth: true
    spacing: 6

    Text {
        text:                root.label
        color:               Style.textSecondary
        font.family:         Style.fontMono
        font.pixelSize:      Style.fontSizeBody
        Layout.minimumWidth: root.labelWidth
        elide:               Text.ElideRight
    }

    Item {
        visible:          !root.fill
        Layout.fillWidth: true
    }
}
