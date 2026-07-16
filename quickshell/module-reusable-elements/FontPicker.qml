import QtQuick
import QtQuick.Controls

Item {
    id: root

    property string value: ""
    signal committed(string fontFamily)

    implicitHeight: Style.fontSizeBody + Style.panelElementVpadding

    readonly property var _allFonts: Qt.fontFamilies().sort()

    onValueChanged: { if (!_field.activeFocus) _field.text = root.value }
    Component.onCompleted: _field.text = root.value

    // Input field
    Rectangle {
        anchors.fill: parent
        radius: Style.panelElementRadius
        color: Style.surfaceMidColor
        border.width: Style.elementBorderWidth
        border.color: _field.activeFocus ? Style.accentColor : Style.borderSoftColor

        TextInput {
            id: _field
            anchors {
                left: parent.left; right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 6; rightMargin: 6
            }
            color: Style.textNormal
            font.family: Style.fontMono
            font.pixelSize: Style.fontSizeBody
            selectByMouse: true
            clip: true

            onActiveFocusChanged: if (activeFocus) _popup.open()
            onTextEdited:         _popup.open()
            onAccepted: {
                root.committed(text)
                focus = false
                _popup.close()
            }
        }
    }

    // Drop-down popup
    Popup {
        id: _popup
        y:       root.height + 2
        width:   root.width
        height:  Math.min(_list.contentHeight, 168)
        padding: 1
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        background: Rectangle {
            color:        Style.surfaceLowColor
            radius:       Style.panelElementRadius
            border.color: Style.borderFaintColor
            border.width: 1
        }

        ListView {
            id: _list
            anchors.fill: parent
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            model: {
                var q = _field.text.toLowerCase()
                if (q === "") return root._allFonts
                return root._allFonts.filter(function(f) {
                    return f.toLowerCase().indexOf(q) !== -1
                })
            }

            delegate: Item {
                width:  _list.width
                height: 22

                Rectangle {
                    anchors.fill: parent
                    color:  _ma.containsMouse ? Style.accentBgColor : "transparent"
                    radius: Style.panelElementRadius
                }

                Text {
                    anchors {
                        left: parent.left; right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 6; rightMargin: 6
                    }
                    text:           modelData
                    color:          Style.textNormal
                    font.family:    Style.fontMono
                    font.pixelSize: Style.fontSizeBody
                    clip:           true
                    elide:          Text.ElideRight
                }

                MouseArea {
                    id: _ma
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        _field.text = modelData
                        root.committed(modelData)
                        _popup.close()
                    }
                }
            }
        }
    }
}
