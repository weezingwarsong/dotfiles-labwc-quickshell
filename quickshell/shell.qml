import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import "components"

ShellRoot {
    id: root

    // "time" | "workspace" | "recording" | "recordingSaved" | "mpris" | "window"
    property string activeModule: "time"
    property string currentWorkspace: "1"
    property bool   isRecording: false
    property MprisPlayer mprisPlayer: null   // player to display (kept during 1s pause window)
    property bool   isMprisActive: false     // true only while actually playing
    property var    wallpapers: []
    property var    _wallpaperBuf: []
    property var    ws1Windows: []
    property var    ws2Windows: []
    property string activeWindow: ""

    // Drives where workspace/recording timers return to
    readonly property string restingModule: isMprisActive ? "mpris" : "time"

    function _syncMpris() {
        var playing = null
        var paused  = null
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (p.playbackState === MprisPlaybackState.Playing && !playing) playing = p
            else if (p.playbackState === MprisPlaybackState.Paused  && !paused)  paused  = p
        }
        var wasActive = root.isMprisActive
        root.isMprisActive = (playing !== null)
        if (playing !== null) {
            mprisTimer.stop()
            root.mprisPlayer = playing
            if (!root.isRecording && root.activeModule !== "workspace" && root.activeModule !== "window")
                root.activeModule = "mpris"
        } else if (wasActive) {
            if (paused !== null) root.mprisPlayer = paused
            var comp = moduleLoader.item
            if (root.activeModule === "mpris" && (!comp || !comp.hovered))
                mprisTimer.restart()
        }
    }

    readonly property url currentWallpaper: {
        var idx = parseInt(currentWorkspace) - 1
        if (idx >= 0 && idx < wallpapers.length)
            return "file://" + wallpapers[idx]
        return ""
    }

    WallpaperWindow {
        source: root.currentWallpaper
    }

    PanelWindow {
        id: panel
        anchors.top: true
        color: "transparent"
        margins.top: 4
        exclusiveZone: 28

        implicitWidth: root.activeModule === "window"
            ? Math.round(Screen.width * 0.20)
            : Math.round(Screen.width * 0.10)
        implicitHeight: moduleLoader.implicitHeight

        WlrLayershell.keyboardFocus: root.activeModule === "window"
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        Item {
            anchors.fill: parent
            clip: true
            focus: root.activeModule === "window"

            Keys.onPressed: function(event) {
                if (root.activeModule !== "window") return
                if (event.key === Qt.Key_Escape) {
                    root.activeModule = root.restingModule
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.MetaModifier)) {
                    root.activeModule = root.restingModule
                    event.accepted = true
                }
            }

            Loader {
                id: moduleLoader
                width: parent.width
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                source: {
                    if (root.activeModule === "workspace")
                        return Qt.resolvedUrl("components/Workspace.qml")
                    if (root.activeModule === "recording" || root.activeModule === "recordingSaved")
                        return Qt.resolvedUrl("components/RecordingStatus.qml")
                    if (root.activeModule === "mpris")
                        return Qt.resolvedUrl("components/Mpris.qml")
                    if (root.activeModule === "window")
                        return Qt.resolvedUrl("components/Window.qml")
                    return Qt.resolvedUrl("components/Time.qml")
                }
                onLoaded: {
                    if (root.activeModule === "workspace")
                        item.workspace = Qt.binding(() => root.currentWorkspace)
                    if (root.activeModule === "recording" || root.activeModule === "recordingSaved")
                        item.saved = Qt.binding(() => root.activeModule === "recordingSaved")
                    if (root.activeModule === "mpris") {
                        item.player = Qt.binding(() => root.mprisPlayer)
                        item.wantsDismiss.connect(function() {
                            if (!root.isMprisActive && root.activeModule === "mpris")
                                mprisTimer.restart()
                        })
                    }
                    if (root.activeModule === "window") {
                        item.ws1Windows = Qt.binding(() => root.ws1Windows)
                        item.ws2Windows = Qt.binding(() => root.ws2Windows)
                        item.activeWindow = Qt.binding(() => root.activeWindow)
                        item.windowFocused.connect(function() {
                            root.activeModule = root.restingModule
                        })
                    }
                }
            }
        }
    }

    // Return to resting module after workspace flash
    Timer {
        id: workspaceTimer
        interval: 1000
        onTriggered: if (root.activeModule === "workspace") root.activeModule = root.restingModule
    }

    // Return to resting module after "RECORDING SAVED" flash
    Timer {
        id: recordingTimer
        interval: 1000
        onTriggered: root.activeModule = root.restingModule
    }

    // Return to time 1s after MPRIS stops playing; clear player ref after leaving
    Timer {
        id: mprisTimer
        interval: 1000
        onTriggered: {
            if (root.activeModule === "mpris") root.activeModule = "time"
            root.mprisPlayer = null
        }
    }

    // Watch each player's playback state reactively
    Instantiator {
        model: Mpris.players
        delegate: QtObject {
            required property var modelData
            property var _conn: Connections {
                target: modelData
                function onPlaybackStateChanged() { root._syncMpris() }
            }
        }
        onObjectAdded: { root._syncMpris() }
        onObjectRemoved: { root._syncMpris() }
    }

    // Poll recording state every second
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: if (!recordingCheck.running) recordingCheck.running = true
    }

    Process {
        id: recordingCheck
        command: ["sh", "-c", "test -f /tmp/gsr-pid && kill -0 \"$(cat /tmp/gsr-pid)\" 2>/dev/null"]
        onExited: function(code, signal) {
            var nowRecording = (code === 0)
            if (nowRecording && !root.isRecording) {
                root.isRecording = true
                root.activeModule = "recording"
                workspaceTimer.stop()
                recordingTimer.stop()
            } else if (!nowRecording && root.isRecording) {
                root.isRecording = false
                root.activeModule = "recordingSaved"
                recordingTimer.restart()
            }
        }
    }

    // FIFO-based toggle for window-switch module — labwc W-Tab writes to this pipe
    Process {
        id: windowToggleReader
        command: ["sh", "-c",
            "rm -f /tmp/qs-window-toggle; mkfifo /tmp/qs-window-toggle; " +
            "while true; do cat /tmp/qs-window-toggle; done"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "toggle") return
                if (root.activeModule === "window")
                    root.activeModule = root.restingModule
                else
                    root.activeModule = "window"
            }
        }
    }

    // Persistent window tracker — reads from FIFO written by qs-toplevel-watcher
    // (started via scripts/start-watchers.sh before quickshell in autostart).
    // The while-loop restarts cat across the brief gap when the daemon restarts.
    Process {
        id: toplevelWatcher
        command: ["sh", "-c",
            "[ -p /tmp/qs-toplevels ] || mkfifo /tmp/qs-toplevels; " +
            "while true; do cat /tmp/qs-toplevels; done"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var d = JSON.parse(line.trim())
                    root.ws1Windows  = d.ws1    || []
                    root.ws2Windows  = d.ws2    || []
                    root.activeWindow = d.active || ""
                } catch(e) {}
            }
        }
    }

    Process {
        id: wallpaperScanner
        command: ["sh", "-c", "find \"$HOME/.config/quickshell/wallpaper\" -maxdepth 1 -type f | sort 2>/dev/null"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var f = line.trim()
                if (f !== "") root._wallpaperBuf.push(f)
            }
        }
        onExited: function(code, signal) {
            root.wallpapers = root._wallpaperBuf.slice()
        }
    }

    // Workspace tracker — reads from FIFO written by qs-workspace-watcher.
    Process {
        id: wsWatcher
        command: ["sh", "-c",
            "[ -p /tmp/qs-workspace ] || mkfifo /tmp/qs-workspace; " +
            "while true; do cat /tmp/qs-workspace; done"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var ws = line.trim()
                if (ws !== "") {
                    root.currentWorkspace = ws
                    if (!root.isRecording) {
                        root.activeModule = "workspace"
                        workspaceTimer.restart()
                    }
                }
            }
        }
    }
}
