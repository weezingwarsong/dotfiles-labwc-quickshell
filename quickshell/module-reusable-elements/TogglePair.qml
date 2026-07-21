import QtQuick
import QtQuick.Layouts

// Single-button toggle that shows the current state at rest.
// On hover the current label slides left, revealing the alternative —
// previewing what a click will do. On click: flash feedback, state switches.
//
// variant "normal"  — both labels have equal visual weight
// variant "yesno"   — labelA is the "positive" state (accent bg, stronger text)
Item {
    id: root

    property string labelA:  ""
    property string labelB:  ""
    property int    selected: 0
    property string variant:    "normal"
    property string fontFamily: Style.fontMono
    property color  colorA:     Style.textNormal
    property color  colorB:     Style.textSecondary

    signal toggled(int index)

    // Width: max of the two label widths + padding, capped at 250px
    implicitWidth:  Math.min(
        Math.max(_mA.implicitWidth, _mB.implicitWidth) + Style.panelElementHpadding,
        250
    )
    implicitHeight: Style.buttonHeight

    clip: true

    // ── Background ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius:       Style.panelElementRadius
        border.width: Style.elementBorderWidth
        border.color: Style.borderFaintColor
        color: (variant === "yesno" && selected === 0)
               ? Style.accentBgColor : Style.surfaceLowColor
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // ── Hidden measurers (drive implicitWidth without affecting layout) ────────
    Text { id: _mA; visible: false; text: labelA; font.family: root.fontFamily; font.pixelSize: Style.fontSizeBody }
    Text { id: _mB; visible: false; text: labelB; font.family: root.fontFamily; font.pixelSize: Style.fontSizeBody }

    // ── Label A ───────────────────────────────────────────────────────────────
    // active (selected=0): shows at x=0, slides out left on hover
    // inactive (selected=1): waits at x=width, slides in on hover as preview
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width:               parent.width
        horizontalAlignment: Text.AlignHCenter
        elide:               Text.ElideRight
        text:                labelA
        font.family:         root.fontFamily
        font.pixelSize:      Style.fontSizeBody
        color: (variant === "yesno")
               ? (selected === 0 ? Style.textOnAccent : Style.textAccent)
               : root.colorA

        x: selected === 0
           ? (_hover.hovered ? -parent.width : 0)
           : (_hover.hovered ?  0 : parent.width)
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutCubic } }
    }

    // ── Label B ───────────────────────────────────────────────────────────────
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width:               parent.width
        horizontalAlignment: Text.AlignHCenter
        elide:               Text.ElideRight
        text:                labelB
        font.family:         root.fontFamily
        font.pixelSize:      Style.fontSizeBody
        color: (variant === "yesno")
               ? (selected === 1 ? Style.textNormal : Style.textSecondary)
               : root.colorB

        x: selected === 1
           ? (_hover.hovered ? -parent.width : 0)
           : (_hover.hovered ?  0 : parent.width)
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutCubic } }
    }

    // ── Click flash ───────────────────────────────────────────────────────────
    Rectangle {
        id:     _flash
        anchors.fill: parent
        radius: Style.panelElementRadius
        color:  Style.accentColor
        opacity: 0
    }
    NumberAnimation {
        id: _flashOut; target: _flash; property: "opacity"
        to: 0; duration: 350; easing.type: Easing.OutCubic
    }

    // ── Interaction ───────────────────────────────────────────────────────────
    HoverHandler { id: _hover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        onTapped: {
            _flash.opacity = 0.22
            _flashOut.start()
            root.toggled(root.selected === 0 ? 1 : 0)
        }
    }
}
