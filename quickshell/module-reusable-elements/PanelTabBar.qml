import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var labels:   []
    property var glyphs:   []   // optional; parallel to labels — empty string collapses glyph row
    property int selected: 0

    signal toggled(int index)

    implicitHeight: _row.implicitHeight
    Layout.fillWidth: true

    // Tab buttons
    RowLayout {
        id: _row
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
        spacing: 0

        Repeater {
            model: root.labels

            Item {
                required property string modelData
                required property int    index

                readonly property string _glyph: index < root.glyphs.length ? root.glyphs[index] : ""

                Layout.fillWidth: true
                implicitHeight:   _content.implicitHeight + Style.panelElementVpadding

                // MD3 state layer — 8% primary on hover
                Rectangle {
                    anchors.fill: parent
                    color:        Style.surfaceHoverColor
                    opacity:      _hover.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                }

                ColumnLayout {
                    id:               _content
                    anchors.centerIn: parent
                    spacing:          2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible:          _glyph !== ""
                        text:             _glyph
                        font.family:      Style.fontNerd
                        font.pixelSize:   Style.fontSizeBody
                        color:            root.selected === index ? Style.accentColor : Style.textSecondary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text:             modelData
                        font.family:      Style.fontMono
                        font.pixelSize:   Style.fontSizeHeading
                        color:            root.selected === index ? Style.accentColor : Style.textSecondary
                    }
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

    // Sliding accent indicator — animates x on tab change; hidden when selected < 0
    Rectangle {
        id: _indicator
        anchors.bottom: parent.bottom
        height:  2
        width:   root.labels.length > 0 ? parent.width / root.labels.length : parent.width
        color:   Style.accentColor
        visible: root.selected >= 0 && root.selected < root.labels.length
        x:       root.selected * width

        Behavior on x {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }
}
