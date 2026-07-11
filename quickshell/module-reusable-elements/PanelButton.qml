import QtQuick
import QtQuick.Controls as QQC

Rectangle {
    id: root

    property string label:   ""
    property string icon:    ""
    property string tooltip: ""
    property string variant: "default"  // "default" | "accent" | "critical"

    signal clicked()

    implicitWidth:  _content.implicitWidth + 20
    implicitHeight: Style.buttonHeight
    radius:         Style.radSm
    border.width:   Style.elementBorderWidth
    border.color:   Style.borderSoftColor

    color: {
        if (variant === "accent")   return _hover.hovered ? Style.accentBgHover   : Style.accentBgColor
        if (variant === "critical") return _hover.hovered ? Style.criticalBgColor : Style.transparent
        return _hover.hovered ? Style.surfaceLowColor : Style.transparent
    }

    property color _textColor: {
        if (variant === "accent")   return Style.textMuted
        if (variant === "critical") return Style.textCritical
        return Style.textSecondary
    }

    Row {
        id: _content
        anchors.centerIn: parent
        spacing: root.icon !== "" ? 6 : 0

        Text {
            visible:        root.icon !== ""
            text:           root.icon
            font.family:    Style.fontNerd
            font.pixelSize: Style.fontSizeBody
            color:          root._textColor
        }

        Text {
            text:           root.label
            font.family:    Style.fontMono
            font.pixelSize: Style.fontSizeBody
            color:          root._textColor
        }
    }

    HoverHandler {
        id: _hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }

    QQC.ToolTip {
        visible: _hover.hovered && root.tooltip !== ""
        text:    root.tooltip
        delay:   500
    }
}
