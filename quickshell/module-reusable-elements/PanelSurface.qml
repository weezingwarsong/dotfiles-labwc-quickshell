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
    property var settingsProcess: null
    property var clockProcess:    null
    property var calendarProcess: null
    property var tasksProcess:    null
    property var weatherProcess:  null
    property var timerProcess:    null
    property var toplevelProcess: null

    signal dismissRequested()
    signal navigateRequested(int direction)

    screen: Quickshell.screens[0]
    anchors.top: true
    exclusiveZone: 0
    color: "transparent"
    margins.top: Screen.width * 0.10

    // Max height at the symmetry point: gap above == gap below.
    readonly property real _maxHeight: Screen.height - 2 * margins.top

    // Strip above the panel rectangle reserved for the floating nav buttons.
    // Zero for window switcher — excluded from nav, no bar needed.
    readonly property int _navBarHeight: root.activePanel !== "windowSwitcher" ? 30 : 0

    implicitWidth:  Screen.width * 0.15
    implicitHeight: loader.item
        ? Math.min(loader.item.implicitHeight + _navBarHeight, _maxHeight)
        : Screen.width * 0.15

    visible: shouldShow

    // All panels grab exclusive keyboard focus immediately on open — ESC and
    // arrow keys work without requiring a click first.
    WlrLayershell.keyboardFocus: root.shouldShow
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    // Floating ‹ › nav buttons above the panel rectangle. Hidden for window switcher.
    Row {
        visible: root.activePanel !== "" && root.activePanel !== "windowSwitcher"
        anchors { top: parent.top; right: parent.right; topMargin: 4; rightMargin: 4 }
        spacing: 4

        PanelButton {
            label: "‹"
            onClicked: root.navigateRequested(-1)
        }
        PanelButton {
            label: "›"
            onClicked: root.navigateRequested(+1)
        }
    }

    Loader {
        id: loader
        anchors { fill: parent; topMargin: root._navBarHeight }
        focus: true

        Keys.onEscapePressed: (event) => {
            root.dismissRequested()
            event.accepted = true
        }
        Keys.onLeftPressed: (event) => {
            if (root.activePanel !== "windowSwitcher") {
                root.navigateRequested(-1)
                event.accepted = true
            }
        }
        Keys.onRightPressed: (event) => {
            if (root.activePanel !== "windowSwitcher") {
                root.navigateRequested(+1)
                event.accepted = true
            }
        }

        source: {
            if (root.activePanel === "calendar")       return Qt.resolvedUrl("../module-panels/CalendarPanel.qml")
            if (root.activePanel === "windowSwitcher") return Qt.resolvedUrl("../module-panels/WindowSwitcherPanel.qml")
            if (root.activePanel === "settings")       return Qt.resolvedUrl("../module-panels/SettingsPanel.qml")
            return ""
        }
        onLoaded: {
            if (!item) return
            if (root.activePanel === "windowSwitcher") {
                item.toplevelProcess = Qt.binding(function() { return root.toplevelProcess })
                item.dismissed.connect(function() { root.dismissRequested() })
                return
            }
            if (root.activePanel === "settings") {
                item.settingsProcess  = Qt.binding(function() { return root.settingsProcess  })
                item.calendarProcess  = Qt.binding(function() { return root.calendarProcess  })
                item.tasksProcess     = Qt.binding(function() { return root.tasksProcess     })
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
