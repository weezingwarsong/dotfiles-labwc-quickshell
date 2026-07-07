import QtQuick

Rectangle {
    property bool active: true

    width:  8
    height: 8
    radius: 4
    color: active ? Style.textSuccess : Style.textCritical
}
