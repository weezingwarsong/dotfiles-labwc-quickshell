import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property var  toplevelProcess: null
    property bool isOpen:          false

    readonly property real _maxH: Screen.height * 0.6

    function toggle() { root.isOpen = !root.isOpen }

    screen:        Quickshell.screens[0]
    anchors.left:  true
    anchors.right: true
    anchors.top:   true
    anchors.bottom: true
    exclusiveZone: 0
    color:         "transparent"
    visible:       root.isOpen

    WlrLayershell.keyboardFocus: root.isOpen
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    Shortcut {
        sequence: "Escape"
        context:  Qt.WindowShortcut
        onActivated: root.isOpen = false
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.isOpen = false
    }

    Item {
        id: _container
        x:      Math.round((parent.width - width) / 2)
        y:      Math.round(Screen.width * (Style.panelOffsetY / 100.0))
        width:  Math.round(Screen.width * (Style.panelWidth / 100.0))
        height: Math.min(_view.implicitHeight, root._maxH)

        MouseArea { anchors.fill: parent; z: 0 }

        Rectangle {
            anchors.fill:  parent
            color:         Style.panelBgColor
            radius:        Style.panelRadius
            border.width:  Style.elementBorderWidth
            border.color:  Style.panelBorderColor
            clip:          true
        }

        WindowSwitcherView {
            id: _view
            anchors.fill: parent
            toplevelProcess: root.toplevelProcess
            onDismissed: root.isOpen = false
        }
    }
}
