import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property int hpadding: Style.panelCardHpadding
    property int vpadding: Style.panelCardVpadding

    default property alias content: _inner.data

    implicitHeight: _inner.y + _inner.height + vpadding

    color:        Style.surfaceLowColor
    radius:       Style.panelElementRadius
    border.width: Style.borderWidth
    border.color: Style.borderFaintColor

    Item {
        id: _inner
        anchors {
            left: parent.left;   leftMargin:  root.hpadding
            right: parent.right; rightMargin: root.hpadding
            top: parent.top;     topMargin:   root.vpadding
        }
        height: childrenRect.height
    }
}
