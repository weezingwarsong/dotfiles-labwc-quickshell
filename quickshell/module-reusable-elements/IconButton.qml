import QtQuick
import QtQuick.Controls as QQC

Rectangle {
    id: root

    property string label:      ""
    property string fontFamily: Style.fontNerd
    property string tooltip:    ""
    property string variant:    "default"  // "default" | "critical" | "important"

    signal clicked()

    implicitWidth:  Style.fontSizeBody + Style.panelElementVpadding
    implicitHeight: Style.fontSizeBody + Style.panelElementVpadding
    radius:         Style.panelElementRadius

    color: {
        if (variant === "important") return _tap.active    ? Style.accentColor
                                          : _hover.hovered ? Style.accentBgHover
                                          : Style.accentBgColor
        if (variant === "critical")  return _tap.active    ? Style.criticalBgColor
                                          : _hover.hovered ? Style.criticalHoverColor
                                          : Style.transparent
        return                              _tap.active    ? Style.accentBgColor
                                          : _hover.hovered ? Style.surfaceHoverColor
                                          : Style.transparent
    }

    Text {
        anchors.centerIn: parent
        text:           root.label
        font.family:    root.fontFamily
        font.pixelSize: Style.fontSizeBody
        color: {
            if (root.variant === "important") return Style.textOnAccent
            if (root.variant === "critical")  return Style.textCritical
            return _tap.active    ? Style.textOnAccent
                 : _hover.hovered ? Style.textNormal
                 : Style.textSecondary
        }
    }

    HoverHandler { id: _hover; cursorShape: Qt.PointingHandCursor }
    TapHandler   { id: _tap;   onTapped: root.clicked() }

    QQC.ToolTip {
        visible: _hover.hovered && root.tooltip !== ""
        text:    root.tooltip
        delay:   500
    }
}
