import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var labels:   []
    property int selected: 0

    signal toggled(int index)

    implicitHeight: Style.buttonHeight
    Layout.fillWidth: true

    // Tab buttons
    Row {
        id: _row
        anchors.fill: parent

        Repeater {
            model: root.labels

            Item {
                required property string modelData
                required property int    index

                width:  _row.width / root.labels.length
                height: _row.height

                // MD3 state layer — 8% primary on hover
                Rectangle {
                    anchors.fill: parent
                    color:        Style.surfaceHoverColor
                    opacity:      _hover.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }

                Text {
                    anchors.centerIn: parent
                    text:             modelData
                    font.family:      Style.fontMono
                    font.pixelSize:   Style.fontSizeHeading
                    color:            root.selected === index
                                      ? Style.accentColor
                                      : Style.textSecondary
                }

                HoverHandler { id: _hover; cursorShape: Qt.PointingHandCursor }
                TapHandler   { onTapped: if (root.selected !== index) root.toggled(index) }
            }
        }
    }

    // Full-width bottom divider (muted track)
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color:  Style.borderFaintColor
    }

    // Sliding accent indicator — animates x on tab change
    Rectangle {
        id: _indicator
        anchors.bottom: parent.bottom
        height: 2
        width:  root.labels.length > 0 ? parent.width / root.labels.length : parent.width
        color:  Style.accentColor
        x:      root.selected * width

        Behavior on x {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }
}
