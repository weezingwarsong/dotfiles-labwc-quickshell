import QtQuick
import QtQuick.Controls as QQC

Rectangle {
    id: root

    property string label:   ""
    property string icon:    ""
    property string tooltip: ""
    property string variant: "default"  // "default" | "accent" | "critical" | "text"

    signal clicked()

    implicitWidth:  Math.min(Math.max(_content.implicitWidth + Style.panelElementHpadding, 24), 300)
    implicitHeight: Math.max(Style.buttonHeight, _content.implicitHeight + Style.panelElementVpadding)
    radius:         Style.panelElementRadius
    border.width:   variant === "default" ? Style.elementBorderWidth : 0
    border.color:   Style.borderSoftColor

    color: {
        if (variant === "accent")   return _hover.hovered ? Style.accentBgHover     : Style.accentBgColor
        if (variant === "critical") return _hover.hovered ? Style.criticalHoverColor : Style.transparent
        return _hover.hovered ? Style.surfaceHoverColor : Style.transparent
    }

    property color _textColor: {
        if (variant === "accent")   return Style.textOnAccent
        if (variant === "critical") return Style.textCritical
        if (variant === "text")     return Style.textAccent
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
