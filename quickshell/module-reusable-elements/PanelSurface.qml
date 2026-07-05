import Quickshell
import Quickshell.Wayland
import QtQuick

// Separate window surface for panels, anchored below the pill.
// Dumb renderer — no logic. All show/hide decisions come from PanelController.
// Geometry authority: all panels share this fixed size and position.
PanelWindow {
    id: root

    property string activePanel: ""
    property bool shouldShow: false

    // Injected processes — forwarded to whatever panel is currently loaded
    property var clockProcess:    null
    property var calendarProcess: null
    property var tasksProcess:    null
    property var weatherProcess:  null
    property var timerProcess:    null
    property var toplevelProcess: null

    signal dismissRequested()

    screen: Quickshell.screens[0]
    anchors.top: true
    exclusiveZone: 0
    color: "transparent"
    margins.top: Screen.width * 0.10

    implicitWidth:  Screen.width * 0.15
    implicitHeight: Screen.width * 0.15

    visible: shouldShow

    // Window switcher needs exclusive keyboard focus to capture TextInput events.
    WlrLayershell.keyboardFocus: root.activePanel === "windowSwitcher"
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    Loader {
        id: loader
        anchors.fill: parent
        focus: true
        source: {
            if (root.activePanel === "calendar")       return Qt.resolvedUrl("../module-panels/CalendarPanel.qml")
            if (root.activePanel === "windowSwitcher") return Qt.resolvedUrl("../module-panels/WindowSwitcherPanel.qml")
            return ""
        }
        onLoaded: {
            if (!item) return
            if (root.activePanel === "windowSwitcher") {
                item.toplevelProcess = Qt.binding(function() { return root.toplevelProcess })
                item.dismissed.connect(function() { root.dismissRequested() })
                return
            }
            item.clockProcess    = Qt.binding(function() { return root.clockProcess    })
            item.calendarProcess = Qt.binding(function() { return root.calendarProcess })
            item.tasksProcess    = Qt.binding(function() { return root.tasksProcess    })
            item.weatherProcess  = Qt.binding(function() { return root.weatherProcess  })
            item.timerProcess    = Qt.binding(function() { return root.timerProcess    })
        }
    }
}
