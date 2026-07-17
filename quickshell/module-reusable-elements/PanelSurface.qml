import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Fullscreen transparent overlay that hosts the active panel.
// PanelContainer owns the visual chrome (background, border, radius) and the
// NavBar. Panel modules are pure content — no chrome, no NavBar of their own.
// A fullscreen MouseArea (z:0) behind the container dismisses on click-outside.
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
    property var screenshotProcess:   null
    property var screenrecProcess:    null
    property int notificationInitialTab: 0

    signal dismissRequested()
    signal navigateRequested(int direction)

    screen: Quickshell.screens[0]
    anchors.left:   true
    anchors.right:  true
    anchors.top:    true
    anchors.bottom: true
    exclusiveZone:  0
    color:          "transparent"

    readonly property real _panelY:     Screen.width * (Style.panelOffsetY / 100.0)
    readonly property real _panelWidth: Screen.width * (Style.panelWidth   / 100.0)
    readonly property real _maxHeight:  Screen.height - 2 * _panelY

    // Max space for row-2 content: total cap minus NavBar, col spacing, and top+bottom chrome padding.
    readonly property real _maxContentHeight:
        _maxHeight - _navBar.implicitHeight - _col.spacing - Style.panelMargin * 2

    visible: shouldShow

    WlrLayershell.keyboardFocus: root.shouldShow
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    Shortcut {
        sequence: "Escape"
        context:  Qt.WindowShortcut
        onActivated: root.dismissRequested()
    }

    // ── Click-outside dismiss layer ───────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        z: 0
        onClicked: root.dismissRequested()
    }

    // ── Panel container ───────────────────────────────────────────────────────
    // Fixed width; height follows _bg which owns the cap formula.
    Item {
        id: panelContainer
        x:      Math.round((parent.width - root._panelWidth) / 2)
        y:      root._panelY
        width:  root._panelWidth
        height: _bg.height
        z: 1

        MouseArea { anchors.fill: parent; z: 0 }

        Rectangle {
            id: _bg
            anchors { left: parent.left; right: parent.right; top: parent.top }
            // Owns the height cap: NavBar + col spacing + capped content + top/bottom padding.
            height: _navBar.implicitHeight + _col.spacing
                  + Math.min(_loader.item ? _loader.item.implicitHeight : 0, root._maxContentHeight)
                  + Style.panelMargin * 2
            radius:       Style.panelRadius
            color:        Style.panelBgColor
            border.color: Style.panelBorderColor
            border.width: Style.borderWidth
            clip:         true

            ColumnLayout {
                id: _col
                anchors.top:              parent.top
                anchors.topMargin:        Style.panelMargin
                anchors.horizontalCenter: parent.horizontalCenter
                width:   parent.width - Style.panelMargin * 2
                spacing: Style.panelCardVpadding

                PanelNavBar {
                    id: _navBar
                    activePanel: root.activePanel
                    onNavigateRequested: (dir) => root.navigateRequested(dir)
                }

                Loader {
                    id: _loader
                    focus: true
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(
                        item ? item.implicitHeight : 0,
                        root._maxContentHeight
                    )
                    source: {
                        switch (root.activePanel) {
                            case "settings":      return "../module-panels/SettingsPanel.qml"
                            case "calendar":      return "../module-panels/CalendarPanel.qml"
                            case "mediaPlayer":   return "../module-panels/MediaPlayerPanel.qml"
                            case "wallpaper":     return "../module-panels/WallpaperPanel.qml"
                            case "notifications": return "../module-panels/NotificationPanel.qml"
                            case "control":       return "../module-panels/ControlPanel.qml"
                            default:              return ""
                        }
                    }
                    Keys.onLeftPressed:  (event) => { root.navigateRequested(-1); event.accepted = true }
                    Keys.onRightPressed: (event) => { root.navigateRequested(+1); event.accepted = true }

                    onLoaded: {
                        var it = item
                        if (!it) return
                        switch (root.activePanel) {
                            case "settings":
                                it.settingsProcess  = Qt.binding(() => root.settingsProcess)
                                it.calendarProcess  = Qt.binding(() => root.calendarProcess)
                                it.tasksProcess     = Qt.binding(() => root.tasksProcess)
                                it.wallpaperProcess = Qt.binding(() => root.wallpaperProcess)
                                break
                            case "calendar":
                                it.calendarProcess = Qt.binding(() => root.calendarProcess)
                                it.tasksProcess    = Qt.binding(() => root.tasksProcess)
                                it.clockProcess    = Qt.binding(() => root.clockProcess)
                                break
                            case "mediaPlayer":
                                it.mprisProcess    = Qt.binding(() => root.mprisProcess)
                                it.toplevelProcess = Qt.binding(() => root.toplevelProcess)
                                break
                            case "wallpaper":
                                it.wallpaperProcess = Qt.binding(() => root.wallpaperProcess)
                                break
                            case "notifications":
                                it.notificationServer     = Qt.binding(() => root.notificationServer)
                                it.notificationInitialTab = Qt.binding(() => root.notificationInitialTab)
                                break
                            case "control":
                                it.audioProcess     = Qt.binding(() => root.audioProcess)
                                it.networkProcess   = Qt.binding(() => root.networkProcess)
                                it.screenrecProcess = Qt.binding(() => root.screenrecProcess)
                                break
                        }
                    }
                }
            }
        }
    }

}
