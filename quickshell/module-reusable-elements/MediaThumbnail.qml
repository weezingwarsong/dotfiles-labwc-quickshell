import QtQuick

// Image thumbnail with filename overlay and tap callback.
// Width set by caller; height is derived from the image's actual aspect ratio.
// Square fallback while image is loading.
Rectangle {
    id: root

    property string source:   ""
    property string filename: ""
    signal thumbnailClicked()

    clip:   true
    color:  Style.surfaceLowColor
    radius: Style.panelElementRadius

    implicitHeight: _img.sourceSize.width > 0
        ? Math.round(width * _img.sourceSize.height / _img.sourceSize.width)
        : width

    Image {
        id: _img
        anchors.fill: parent
        source:       root.source !== "" ? ("file://" + root.source) : ""
        fillMode:     Image.PreserveAspectFit
        asynchronous: true
        cache:        false
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height:  _name.implicitHeight + 6
        color:   Qt.rgba(0, 0, 0, 0.45)
        visible: root.filename !== ""

        Text {
            id: _name
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 3 }
            text:           root.filename
            elide:          Text.ElideMiddle
            font.pixelSize: Style.fontSizeSubtle
            font.family:    Style.fontMono
            color:          "white"
        }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler   { onTapped: root.thumbnailClicked() }
}
