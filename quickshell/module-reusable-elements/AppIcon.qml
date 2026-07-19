import QtQuick

Item {
    id: root

    property string iconName: ""
    property string category: ""

    width: height

    readonly property var _glyphs: ({
        "email":    "",
        "im":       "",
        "call":     "",
        "network":  "",
        "device":   "",
        "transfer": "",
        "presence": "",
        "file":     "",
        "sound":    "",
        "volume":   "",
    })

    function _resolveGlyph() {
        if (!root.category) return ""
        return root._glyphs[root.category.split(".")[0]] || ""
    }

    Image {
        id: _img
        anchors.fill: parent
        source: {
            if (!root.iconName) return ""
            if (root.iconName.startsWith("/") || root.iconName.startsWith("file://"))
                return root.iconName
            return "image://icon/" + root.iconName
        }
        fillMode: Image.PreserveAspectFit
        visible:  status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        text:           root._resolveGlyph()
        color:          Style.textSecondary
        font.family:    Style.fontNerd
        font.pixelSize: Math.round(parent.height * 0.7)
        visible:        !_img.visible
    }
}
