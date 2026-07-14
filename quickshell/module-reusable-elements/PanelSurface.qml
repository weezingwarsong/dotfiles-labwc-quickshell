import Quickshell
import Quickshell.Wayland
import QtQuick

// Fullscreen transparent overlay that hosts the active panel.
// The visible panel content sits in a sized Item at the center-top of the screen.
// A fullscreen MouseArea (z:0) behind the panel dismisses on click-outside.
PanelWindow {
    id: root

    property string activePanel: ""
    property bool shouldShow: false

    // Injected processes — forwarded to whatever panel is currently loaded
    property var settingsProcess:  null
    property var clockProcess:     null
    property var calendarProcess:  null
    property var tasksProcess:     null
    property var weatherProcess:   null
    property var timerProcess:     null
    property var toplevelProcess:  null
    property var wallpaperProcess: null
    property var mprisProcess:        null
    property var notificationServer:  null
    property var audioProcess:        null
    property var networkProcess:      null

    signal dismissRequested()
    signal navigateRequested(int direction)

    screen: Quickshell.screens[0]
    anchors.left:   true
    anchors.right:  true
    anchors.top:    true
    anchors.bottom: true
    exclusiveZone:  0
    color:          "transparent"

    // Panel position — same geometry as before, now expressed as coordinates
    // within the fullscreen window rather than window anchors+margins.
    readonly property real _panelY:     Screen.width * 0.10
    readonly property real _panelWidth: Screen.width * 0.15
    readonly property real _maxHeight:  Screen.height - 2 * _panelY

    visible: shouldShow

    // All panels grab exclusive keyboard focus on open so ESC and arrow keys
    // work immediately without a click first.
    WlrLayershell.keyboardFocus: root.shouldShow
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    // ── Click-outside dismiss layer ───────────────────────────────────────────
    // Fullscreen, behind the panel container (z:0).
    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.dismissRequested()
    }

    // ── Panel container ───────────────────────────────────────────────────────
    // Sized to the loaded panel content. A blocking MouseArea (z:0) inside it
    // prevents uncaught clicks from propagating to the dismiss layer above.
    Item {
        id: _container
        x: Math.round((parent.width - root._panelWidth) / 2)
        y: root._panelY
        width: root._panelWidth
        height: loader.height
        z: 1

        MouseArea { anchors.fill: parent; z: 0 }

        Loader {
            id: loader
            x: 0; y: 0
            width: root._panelWidth
            height: item ? Math.min(item.implicitHeight, root._maxHeight) : root._panelWidth
            z: 1
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
                if (root.activePanel === "control")        return Qt.resolvedUrl("../module-panels/ControlPanel.qml")
                if (root.activePanel === "windowSwitcher") return Qt.resolvedUrl("../module-panels/WindowSwitcherPanel.qml")
                if (root.activePanel === "mediaPlayer")    return Qt.resolvedUrl("../module-panels/MediaPlayerPanel.qml")
                if (root.activePanel === "notifications")  return Qt.resolvedUrl("../module-panels/NotificationPanel.qml")
                if (root.activePanel === "settings")       return Qt.resolvedUrl("../module-panels/SettingsPanel.qml")
                if (root.activePanel === "wallpaper")      return Qt.resolvedUrl("../module-panels/WallpaperPanel.qml")
                return ""
            }
            onLoaded: {
                if (!item) return
                if (root.activePanel === "windowSwitcher") {
                    item.toplevelProcess = Qt.binding(function() { return root.toplevelProcess })
                    item.dismissed.connect(function() { root.dismissRequested() })
                    return
                }
                item.activePanel = Qt.binding(function() { return root.activePanel })
                if (root.activePanel === "settings") {
                    item.settingsProcess  = Qt.binding(function() { return root.settingsProcess  })
                    item.calendarProcess  = Qt.binding(function() { return root.calendarProcess  })
                    item.tasksProcess     = Qt.binding(function() { return root.tasksProcess     })
                    item.wallpaperProcess = Qt.binding(function() { return root.wallpaperProcess })
                    item.navigateRequested.connect(function(dir) { root.navigateRequested(dir) })
                    return
                }
                if (root.activePanel === "mediaPlayer") {
                    item.mprisProcess    = Qt.binding(function() { return root.mprisProcess    })
                    item.toplevelProcess = Qt.binding(function() { return root.toplevelProcess })
                    item.navigateRequested.connect(function(dir) { root.navigateRequested(dir) })
                    return
                }
                if (root.activePanel === "notifications") {
                    item.notificationServer = Qt.binding(function() { return root.notificationServer })
                    item.navigateRequested.connect(function(dir) { root.navigateRequested(dir) })
                    return
                }
                if (root.activePanel === "control") {
                    item.audioProcess   = Qt.binding(function() { return root.audioProcess   })
                    item.networkProcess = Qt.binding(function() { return root.networkProcess })
                    item.navigateRequested.connect(function(dir) { root.navigateRequested(dir) })
                    return
                }
                if (root.activePanel === "wallpaper") {
                    item.wallpaperProcess = Qt.binding(function() { return root.wallpaperProcess })
                    item.navigateRequested.connect(function(dir) { root.navigateRequested(dir) })
                    if (root.wallpaperProcess && root.wallpaperProcess.wallpaperDir !== "")
                        root.wallpaperProcess.scanDirectory(root.wallpaperProcess.wallpaperDir)
                    return
                }
                // calendar
                item.clockProcess    = Qt.binding(function() { return root.clockProcess    })
                item.calendarProcess = Qt.binding(function() { return root.calendarProcess })
                item.tasksProcess    = Qt.binding(function() { return root.tasksProcess    })
                item.weatherProcess  = Qt.binding(function() { return root.weatherProcess  })
                item.timerProcess    = Qt.binding(function() { return root.timerProcess    })
                item.navigateRequested.connect(function(dir) { root.navigateRequested(dir) })
            }
        }
    }
}
