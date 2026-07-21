import QtQuick

// Image thumbnail with filename overlay and tap callback.
// Width set by caller; height is derived from the image's actual aspect ratio.
// Square fallback while image is loading.
Rectangle {
    id: root

    property string source:   ""
    property string filename: ""
    property int    fillMode: Image.PreserveAspectFit
    signal thumbnailClicked()
    signal filenameClicked()

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
        fillMode:     root.fillMode
        asynchronous: true
        cache:        false
    }

    Rectangle {
        id:      _overlay
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
    TapHandler {
        onTapped: (eventPoint) => {
            var inOverlay = root.filename !== ""
                         && eventPoint.position.y > (root.height - _overlay.height)
            if (inOverlay)
                root.filenameClicked()
            else
                root.thumbnailClicked()
        }
    }
}
