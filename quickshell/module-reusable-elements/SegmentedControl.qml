import QtQuick
import QtQuick.Layouts

// Mutually exclusive button group (MD3 Segmented Button).
// Pure look-and-feel — no persistence. The caller owns `selected` and handles `onToggled`.
//
// variant "accent"   — active button: accentBgColor / textOnAccent
// variant "critical" — active button: criticalBgColor / textCritical
RowLayout {
    id: root

    property var    model:      []
    property int    selected:   0
    property string variant:    "accent"
    property string fontFamily: Style.fontMono   // override with Style.fontNerd for glyphs

    signal toggled(int index)

    spacing: 2

    Repeater {
        model: root.model

        delegate: Rectangle {
            id: _btn

            required property string modelData
            required property int    index

            property bool _active:  index === root.selected
            property bool _hovered: _hover.hovered

            implicitWidth:  Math.max(24, _label.implicitWidth + Style.panelElementHpadding)
            implicitHeight: Math.max(Style.buttonHeight, _label.implicitHeight + Style.panelElementVpadding)

            radius:       Style.panelElementRadius
            border.width: _active ? 0 : Style.elementBorderWidth
            border.color: Style.borderFaintColor

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

            Text {
                id: _label
                anchors.centerIn: parent
                text:           _btn.modelData
                font.family:    root.fontFamily
                font.pixelSize: Style.fontSizeBody
                color: _btn._active
                    ? (root.variant === "critical" ? Style.textCritical : Style.textOnAccent)
                    : Style.textSecondary
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Rectangle {
                id: _flash
                anchors.fill: parent
                radius:  Style.panelElementRadius
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
                    if (_btn.index !== root.selected) {
                        _flash.opacity = 0.15
                        _flashOut.start()
                        root.toggled(_btn.index)
                    }
                }
            }
        }
    }
}
