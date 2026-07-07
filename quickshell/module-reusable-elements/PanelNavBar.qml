import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    Layout.fillWidth: true

    signal navigateRequested(int direction)

    Item    { Layout.fillWidth: true }
    NavButton { label: "‹"; onClicked: root.navigateRequested(-1) }
    NavButton { label: "›"; onClicked: root.navigateRequested(+1) }
}
