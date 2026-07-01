import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import "components"

ShellRoot {
    id: root

    // priority: "time"=0 | "mpris"=1 | "workspace"=2 | "window"=3 | "recording"/"recordingSaved"=4
    property string activeModule: "time"
    property string currentWorkspace: "1"
    property var    workspaceList:    []
    property bool   isRecording: false
    property MprisPlayer mprisPlayer: null   // player to display (kept during 1s pause window)
    property bool   isMprisActive: false     // true only while actually playing
    property var    wallpapers: []
    property var    _wallpaperBuf: []
    property var    windows: []

    // ── Transition state ──────────────────────────────────────────────────────
    property string _prevModule: ""
    property string _outgoingModule: ""
    property bool   _inTransition: false
    property real   _squishProgress: 0.0
    property int    _squishDir: 1  // +1 from right (higher priority), -1 from left

    // Drives where workspace/recording timers return to
    readonly property string restingModule: isMprisActive ? "mpris" : "time"

    // Priority index for each module.  onActiveModuleChanged compares the old
    // and new indices to set _squishDir: new > old → incoming from right (+1),
    // new < old → incoming from left (-1).
    readonly property var _modPriority: ({
        "time": 0, "mpris": 1, "workspace": 2, "window": 3,
        "recording": 4, "recordingSaved": 4
    })

    function _modSource(mod) {
        if (mod === "workspace")                             return Qt.resolvedUrl("components/Workspace.qml")
        if (mod === "recording" || mod === "recordingSaved") return Qt.resolvedUrl("components/RecordingStatus.qml")
        if (mod === "mpris")                                 return Qt.resolvedUrl("components/Mpris.qml")
        if (mod === "window")                                return Qt.resolvedUrl("components/Window.qml")
        return Qt.resolvedUrl("components/Time.qml")
    }

    // Bind live Qt.binding() properties on a freshly loaded module item.
    // Used for moduleLoader (persistent) and inLoader (incoming during transition).
    function _bindItem(loader, mod) {
        var item = loader.item
        if (!item) return
        if (mod === "workspace") {
            item.workspace      = Qt.binding(() => root.currentWorkspace)
            item.workspaceList  = Qt.binding(() => root.workspaceList)
        }
        if (mod === "recording" || mod === "recordingSaved")
            item.saved = Qt.binding(() => root.activeModule === "recordingSaved")
        if (mod === "mpris") {
            item.player = Qt.binding(() => root.mprisPlayer)
            item.wantsDismiss.connect(function() {
                if (!root.isMprisActive && root.activeModule === "mpris")
                    mprisTimer.restart()
            })
        }
        if (mod === "window") {
            item.windows = Qt.binding(() => root.windows)
            item.windowFocused.connect(function() {
                root.activeModule = root.restingModule
            })
        }
    }

    // Set static snapshot values on outLoader (the exiting module).
    // Plain assignment instead of Qt.binding() — the outgoing content is frozen
    // for the ~180 ms it takes to animate off-screen, so live updates aren't needed.
    function _bindSnapshot(loader, mod) {
        var item = loader.item
        if (!item) return
        if (mod === "workspace") {
            item.workspace     = root.currentWorkspace
            item.workspaceList = root.workspaceList.slice()
        }
        if (mod === "recording" || mod === "recordingSaved") item.saved = (mod === "recordingSaved")
        if (mod === "mpris")                                 item.player = root.mprisPlayer
        if (mod === "window")                                item.windows = root.windows.slice()
    }

    // Initial load: set moduleLoader source here rather than via a computed binding
    // so that onActiveModuleChanged can treat an empty _prevModule as "not yet ready"
    // and skip the transition.  (Children aren't created when the first property-change
    // signal fires during ShellRoot initialisation, so moduleLoader wouldn't exist yet.)
    Component.onCompleted: {
        root._prevModule = root.activeModule
        moduleLoader.source = root._modSource(root.activeModule)
    }

    // Transition sequencing:
    //   1. Capture outgoing source into outLoader before moduleLoader changes.
    //   2. Load the new module into inLoader so both can animate simultaneously.
    //   3. squishAnim drives _squishProgress 0→1; slot widths derive from it.
    //   4. squishAnim.onFinished swaps moduleLoader to the new source and tears
    //      down the transition loaders.
    // moduleLoader.source is intentionally NOT updated here — it stays on the old
    // module so outLoader can copy it.  The swap happens in squishAnim.onFinished.
    onActiveModuleChanged: {
        var prev = root._prevModule
        root._prevModule = root.activeModule

        if (!prev) return  // initial state handled by Component.onCompleted

        var prevIdx = root._modPriority[prev]          !== undefined ? root._modPriority[prev]          : 0
        var newIdx  = root._modPriority[root.activeModule] !== undefined ? root._modPriority[root.activeModule] : 0
        root._squishDir = newIdx >= prevIdx ? 1 : -1

        root._outgoingModule = prev
        outLoader.source = moduleLoader.source
        inLoader.source  = root._modSource(root.activeModule)

        root._inTransition = true
        root._squishProgress = 0
        squishAnim.restart()
    }

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

        implicitWidth: Math.round(Screen.width * 0.10)
        // Clamp to pill height during transitions so expanded panels (MPRIS,
        // window switcher) don't flash open at full height mid-squish.
        implicitHeight: root._inTransition ? Style.pillHeight : moduleLoader.implicitHeight

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

            // ── Persistent loader (shown when not transitioning) ──────────────
            Loader {
                id: moduleLoader
                width: parent.width
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root._inTransition
                onLoaded: root._bindItem(moduleLoader, root.activeModule)
            }

            // ── Squish transition overlay ─────────────────────────────────────
            // Rectangle (not Item) so clip: true follows the rounded pill shape
            // rather than a plain bounding box, keeping capsule corners throughout.
            Rectangle {
                id: squishOverlay
                visible: root._inTransition
                x: 0; y: 0
                width: parent.width
                height: Style.pillHeight
                clip: true
                color: "transparent"
                radius: height / 2

                // Slot geometry invariant (W = squishOverlay.width, p = _squishProgress):
                //   outSlot.width = (1-p) * (W-2)
                //   inSlot.width  =    p  * (W-2)
                //   gap           =         2
                //   total         = outSlot.width + 2 + inSlot.width = W  ✓
                //
                // Each Loader fills its slot exactly (width: parent.width).  The module's
                // pill Rectangle (radius: height/2) therefore shrinks/grows with the slot —
                // Qt clamps radius to width/2 automatically at narrow widths, so both
                // rounded caps stay visible throughout.  No per-loader x math needed;
                // the squishOverlay's own rounded clip handles the outer pill corners.

                // Outgoing (old) — shrinks toward the exit edge
                Item {
                    id: outSlot
                    x: root._squishDir > 0 ? 0 : inSlot.width + 2
                    width: (1.0 - root._squishProgress) * (squishOverlay.width - 2)
                    height: squishOverlay.height

                    Loader {
                        id: outLoader
                        x: 0; width: parent.width; height: parent.height
                        onLoaded: root._bindSnapshot(outLoader, root._outgoingModule)
                    }
                }

                // Incoming (new) — grows in from the entry edge
                Item {
                    id: inSlot
                    x: root._squishDir > 0 ? outSlot.width + 2 : 0
                    width: root._squishProgress * (squishOverlay.width - 2)
                    height: squishOverlay.height

                    Loader {
                        id: inLoader
                        x: 0; width: parent.width; height: parent.height
                        onLoaded: root._bindItem(inLoader, root.activeModule)
                    }
                }
            }
        }
    }

    // Drives the squish: animates _squishProgress 0→1, from which all slot widths
    // and loader positions are derived.  On finish, swap moduleLoader to the new
    // module (triggering _bindItem via onLoaded), then clear the transition loaders
    // and drop the overlay.
    NumberAnimation {
        id: squishAnim
        target: root
        property: "_squishProgress"
        from: 0; to: 1
        duration: Style.transitionDuration
        easing.type: Style.transitionEasing
        onFinished: {
            moduleLoader.source = root._modSource(root.activeModule)
            outLoader.source = ""
            inLoader.source  = ""
            root._inTransition = false
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

    // FIFO-based toggle for window-switch module — labwc W-Tab writes to this pipe.
    // Saves its own PID so the next quickshell session can kill this sh wrapper
    // (and its cat child) by exact PID, avoiding the pkill-matches-self trap.
    Process {
        id: windowToggleReader
        command: ["sh", "-c",
            "P=/tmp/qs-toggle-reader.pid; " +
            "if [ -f \"$P\" ]; then O=$(cat \"$P\"); pkill -P \"$O\" 2>/dev/null; kill \"$O\" 2>/dev/null; fi; " +
            "echo $$ > \"$P\"; " +
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

    // qs-watcher is spawned directly so there are no orphaned FIFO readers.
    // First launch kills any stray qs-watcher left from a previous quickshell
    // session; exec replaces the sh wrapper so only one qs-watcher process runs.
    // On exit (e.g. labwc --reconfigure), watcherRestartTimer respawns after 2 s.
    Process {
        id: watcherReader
        command: ["sh", "-c", "pkill -x qs-watcher 2>/dev/null; sleep 0.3; exec qs-watcher"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var d = JSON.parse(line.trim())
                    var rawWins = d.windows || []
                    var wins = []
                    for (var i = 0; i < rawWins.length; i++) {
                        var w = rawWins[i]
                        wins.push({ app_id: w.app_id || "", title: w.title || "",
                                    states: w.states || {} })
                    }
                    root.windows = wins

                    var wsList = d.workspaces || []
                    if (wsList.length > 0) root.workspaceList = wsList

                    var wsName = d.active_ws_name || ""
                    if (wsName && wsName !== root.currentWorkspace) {
                        root.currentWorkspace = wsName
                        if (!root.isRecording) {
                            root.activeModule = "workspace"
                            workspaceTimer.restart()
                        }
                    }
                } catch(e) {}
            }
        }
        onExited: function(code, signal) { watcherRestartTimer.restart() }
    }

    Timer {
        id: watcherRestartTimer
        interval: 2000
        onTriggered: {
            watcherReader.command = ["qs-watcher"]
            watcherReader.running = true
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

}
