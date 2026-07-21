import QtQuick
import QtQuick.Layouts

// MD3-style mutually exclusive button row.
// All segments share equal width (parent.width / N). Caller owns `selected` and handles `onToggled`.
// variant "accent"   — selected fill: accentBgColor / textOnAccent
// variant "critical" — selected fill: criticalBgColor / textCritical
Rectangle {
    id: root

    property var    model:      []
    property int    selected:   0
    property string variant:    "accent"
    property string fontFamily: Style.fontMono   // override with Style.fontNerd for glyphs

    signal toggled(int index)

    implicitHeight: Style.buttonHeight
    radius:         Style.panelElementRadius
    border.width:   Style.elementBorderWidth
    border.color:   Style.borderFaintColor
    clip:           true
    color:          Style.transparent

    Repeater {
        model: root.model

        delegate: Rectangle {
            id: _seg

            required property string modelData
            required property int    index

            readonly property bool _active:  index === root.selected
            readonly property bool _hovered: _hover.hovered
            readonly property real _segW:    root.model.length > 0
                                             ? root.width / root.model.length : root.width

            x:      index * _seg._segW
            y:      0
            width:  _seg._segW
            height: root.height

            color: {
                if (_active) {
                    if (root.variant === "critical")
                        return _hovered ? Qt.tint(Style.criticalBgColor, Qt.rgba(0, 0, 0, 0.06))
                                       : Style.criticalBgColor
                    return _hovered ? Style.accentBgHover : Style.accentBgColor
                }
                return _hovered ? Style.surfaceHoverColor : Style.transparent
            }
            Behavior on color { ColorAnimation { duration: 120 } }

            // Vertical divider on the left edge of every segment except the first
            Rectangle {
                visible: _seg.index > 0
                x: 0; y: 0
                width:  Style.elementBorderWidth
                height: parent.height
                color:  Style.borderFaintColor
            }

            Text {
                anchors.centerIn: parent
                text:           _seg.modelData
                font.family:    root.fontFamily
                font.pixelSize: Style.fontSizeBody
                color: _seg._active
                    ? (root.variant === "critical" ? Style.textCritical : Style.textOnAccent)
                    : Style.textSecondary
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                id: _flash
                anchors.fill: parent
                color:   root.variant === "critical" ? Style.textCritical : Style.accentColor
                opacity: 0
            }
            NumberAnimation {
                id: _flashOut; target: _flash; property: "opacity"
                to: 0; duration: 300; easing.type: Easing.OutCubic
            }

            HoverHandler { id: _hover; cursorShape: Qt.PointingHandCursor }

            TapHandler {
                onTapped: {
                    if (_seg.index !== root.selected) {
                        _flash.opacity = 0.15
                        _flashOut.start()
                        root.toggled(_seg.index)
                    }
                }
            }
        }
    }
}
