import QtQuick

Item {
    id: root

    property string text: ""
    property color  color: Style.textPrimary
    property int    pauseDuration: 1500
    property int    speed: 20       // ms per pixel of overflow
    property int    maxWidth: 9999  // cap on implicitWidth; pills set this to 200

    property alias font: _label.font

    implicitWidth:  Math.min(_label.implicitWidth, maxWidth)
    implicitHeight: _label.implicitHeight
    clip: true

    onVisibleChanged: if (!visible) _label.x = 0

    Text {
        id: _label
        width:  implicitWidth
        height: parent.height
        verticalAlignment: Text.AlignVCenter
        text:  root.text
        color: root.color
        onTextChanged: { x = 0; _anim.restart() }
    }

    SequentialAnimation {
        id: _anim
        running: root.visible && _label.implicitWidth > root.width
        loops: Animation.Infinite
        PauseAnimation { duration: 500 }
        PauseAnimation { duration: root.pauseDuration }
        NumberAnimation {
            target: _label; property: "x"
            to: -(Math.max(0, _label.implicitWidth - root.width))
            duration: Math.max(1, _label.implicitWidth - root.width) * root.speed
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: root.pauseDuration }
        NumberAnimation { target: _label; property: "x"; to: 0; duration: 0 }
    }
}
