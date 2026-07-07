import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    Layout.fillWidth: true

    signal navigateRequested(int direction)

    Item    { Layout.fillWidth: true }
    IconButton { label: "‹"; onClicked: root.navigateRequested(-1) }
    IconButton { label: "›"; onClicked: root.navigateRequested(+1) }
}
