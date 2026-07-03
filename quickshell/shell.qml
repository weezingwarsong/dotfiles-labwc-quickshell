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
    property var    calendarEvents: []

    // ── Hover-panel state (calendar, MPRIS player) ────────────────────────────
    // `_panelHovered` tracks the mouse over the combined bar+panel region (see
    // the HoverHandler below) — not just the bar itself — so moving from the
    // pill down into its panel doesn't count as leaving. The `*Pinned` flags
    // live here (not on the Time.qml/Mpris.qml panel instances) so they survive
    // the panel being destroyed/recreated during brief interruptions (workspace
    // flash, recording) while that module isn't the active one.
    property bool _panelHovered: false
    property bool _calendarPinned: false
    property bool _mprisPinned: false

    // ── Transition state ──────────────────────────────────────────────────────
    property string _prevModule: ""
    property string _outgoingModule: ""
    property bool   _inTransition: false
    property real   _rollProgress: 0.0       // drives y + opacity (InOutCubic)
    property real   _rollScaleProgress: 0.0  // drives the squash scaleY (InOutQuad)
    property int    _rollDir: 1  // +1 = incoming rolls up from below, -1 = down from above

    // Drives where workspace/recording timers return to
    readonly property string restingModule: isMprisActive ? "mpris" : "time"

    // Priority index for each module.  onActiveModuleChanged compares the old
    // and new indices to set _rollDir: new >= old → incoming rolls in from
    // below (+1), new < old → incoming rolls in from above (-1).
    readonly property var _modPriority: ({
        "time": 0, "mpris": 1, "workspace": 2, "window": 3,
        "recording": 4, "recordingSaved": 4
    })

    // The bar's rolling content — a lightweight icon+text component per module,
    // with no Rectangle/border of its own (the shared `bar` draws that once).
    function _pillSource(mod) {
        if (mod === "workspace")                             return Qt.resolvedUrl("components/WorkspacePill.qml")
        if (mod === "recording" || mod === "recordingSaved") return Qt.resolvedUrl("components/RecordingPill.qml")
        if (mod === "mpris")                                 return Qt.resolvedUrl("components/MprisPill.qml")
        if (mod === "window")                                return Qt.resolvedUrl("components/WindowPill.qml")
        return Qt.resolvedUrl("components/TimePill.qml")
    }

    // The expanded panel anchored below the bar. Workspace/recording have none.
    function _panelSource(mod) {
        if (mod === "mpris")  return Qt.resolvedUrl("components/Mpris.qml")
        if (mod === "window") return Qt.resolvedUrl("components/Window.qml")
        if (mod === "time")   return Qt.resolvedUrl("components/Time.qml")
        return ""
    }

    // Fraction of screen width for the panel *window* (bar + its panel).
    // The bar itself stays a fixed small pill regardless (see `bar.width` in
    // the PanelWindow below) — only the panel content area below it grows.
    // Calendar is a wide dashboard layout; everything else keeps the
    // original narrow width.
    function _panelWidthFrac(mod) {
        return mod === "time" ? 0.20 : 0.10
    }

    // Bind live Qt.binding() properties on a freshly loaded pill item.
    // Used for pillLoader (persistent) and inLoader (incoming during a roll).
    function _bindPill(loader, mod) {
        var item = loader.item
        if (!item) return
        if (mod === "workspace") {
            item.workspace      = Qt.binding(() => root.currentWorkspace)
            item.workspaceList  = Qt.binding(() => root.workspaceList)
        }
        if (mod === "recording" || mod === "recordingSaved")
            item.saved = Qt.binding(() => root.activeModule === "recordingSaved")
        if (mod === "mpris")
            item.player = Qt.binding(() => root.mprisPlayer)
    }

    // Set static snapshot values on outLoader (the exiting pill).
    // Plain assignment instead of Qt.binding() — the outgoing content is frozen
    // for the roll-out, so live updates aren't needed.
    function _bindPillSnapshot(loader, mod) {
        var item = loader.item
        if (!item) return
        if (mod === "workspace") {
            item.workspace     = root.currentWorkspace
            item.workspaceList = root.workspaceList.slice()
        }
        if (mod === "recording" || mod === "recordingSaved") item.saved = (mod === "recordingSaved")
        if (mod === "mpris")                                 item.player = root.mprisPlayer
    }

    // Bind the expanded panel below the bar. Time's and MPRIS's `hovered`/
    // `pinned` both come from the root-level combined-region hover and pin
    // state (see _panelHovered above), since each panel's hover area spans
    // pill+gap+panel, not just the pill.
    function _bindPanel(loader, mod) {
        var item = loader.item
        if (!item) return
        if (mod === "mpris") {
            item.hovered = Qt.binding(() => root._panelHovered)
            item.pinned  = Qt.binding(() => root._mprisPinned)
            item.player  = Qt.binding(() => root.mprisPlayer)
            item.dismissRequested.connect(function() {
                root._mprisPinned = false
                // Re-arm the countdown if still hovering — see the "time" branch below.
                root._updatePanelPinTimer()
            })
        }
        if (mod === "time") {
            item.hovered = Qt.binding(() => root._panelHovered)
            item.pinned  = Qt.binding(() => root._calendarPinned)
            item.events  = Qt.binding(() => root.calendarEvents)
            item.dismissRequested.connect(function() {
                root._calendarPinned = false
                // Dismissing happens while still hovering (you just clicked a
                // button on the panel) — no hover transition occurs to restart
                // the countdown on its own, so re-arm it explicitly here.
                root._updatePanelPinTimer()
            })
        }
        if (mod === "window") {
            item.windows = Qt.binding(() => root.windows)
            item.windowFocused.connect(function() {
                root.activeModule = root.restingModule
            })
        }
    }

    // Starts/stops the 30s "make it permanent" countdown for whichever
    // hover-panel module is currently active; called whenever the combined
    // region's hover state or activeModule changes.
    function _updatePanelPinTimer() {
        if (root._panelHovered && root.activeModule === "time")
            calendarPinTimer.restart()
        else
            calendarPinTimer.stop()

        if (root._panelHovered && root.activeModule === "mpris")
            mprisPinTimer.restart()
        else
            mprisPinTimer.stop()
    }

    Component.onCompleted: {
        root._prevModule = root.activeModule
    }

    // Transition sequencing:
    //   1. Capture outgoing pill source (from the module we're leaving) into outLoader.
    //   2. Load the incoming pill source into inLoader so both can animate simultaneously.
    //   3. rollAnim drives _rollProgress/_rollScaleProgress 0→1; slot y/opacity/scale derive from them.
    //   4. rollAnim.onFinished tears down the transition loaders.
    // pillLoader.source and moduleLoader.source are plain bindings on activeModule
    // (declared where they're used below) — they update immediately, but pillLoader
    // stays invisible (visible: !_inTransition) until the roll finishes, so there's
    // no premature flash of the new content.
    onActiveModuleChanged: {
        var prev = root._prevModule
        root._prevModule = root.activeModule

        if (!prev) return  // initial state handled by Component.onCompleted

        var prevIdx = root._modPriority[prev]          !== undefined ? root._modPriority[prev]          : 0
        var newIdx  = root._modPriority[root.activeModule] !== undefined ? root._modPriority[root.activeModule] : 0
        root._rollDir = newIdx >= prevIdx ? 1 : -1

        root._outgoingModule = prev
        outLoader.source = root._pillSource(prev)
        inLoader.source  = root._pillSource(root.activeModule)

        root._inTransition = true
        root._rollProgress = 0
        root._rollScaleProgress = 0
        rollAnim.restart()

        root._updatePanelPinTimer()
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
            if (root.activeModule === "mpris" && !root._mprisPinned && (!comp || !comp.hovered))
                mprisTimer.restart()
        }
    }

    readonly property url currentWallpaper: {
        var idx = root.workspaceList.indexOf(root.currentWorkspace)
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

        implicitWidth: Math.round(Screen.width * root._panelWidthFrac(root.activeModule))
        // Panels are no longer part of the roll transition, so their height
        // always tracks the panel content directly — no clamping needed.
        implicitHeight: Style.pillHeight + moduleLoader.implicitHeight

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

            // Tracks the mouse over the combined bar+panel region — this Item's
            // bounds already equal Style.pillHeight + moduleLoader.implicitHeight
            // (it fills the PanelWindow, which is sized to exactly that), so this
            // naturally grows to cover a panel the moment it opens. Only consumed
            // when the active module actually has a hover-based panel (time,
            // mpris); harmless no-op otherwise.
            HoverHandler {
                onHoveredChanged: {
                    root._panelHovered = hovered
                    root._updatePanelPinTimer()
                    // MPRIS auto-returns to time 1s after you stop hovering it,
                    // unless it's playing (isMprisActive) or pinned permanent.
                    if (!hovered && root.activeModule === "mpris" &&
                            !root._mprisPinned && !root.isMprisActive)
                        mprisTimer.restart()
                }
            }

            // ── Bar: a rigid rectangle that never moves or resizes. Content
            // rolls vertically inside it between modules, as if printed on a
            // cylinder rotating behind the bar's clipped window. ─────────────
            Rectangle {
                id: bar
                // Fixed to the narrow width regardless of which module is
                // active — only the panel window itself (and moduleLoader
                // below) grows for wide panels like the calendar. Without
                // this, the always-visible pill would stretch to match.
                width: Math.round(Screen.width * 0.10)
                anchors.horizontalCenter: parent.horizontalCenter
                height: Style.pillHeight
                clip: true
                radius: Style.pillRadius
                border.width: Style.pillBorderWidth
                color: root.activeModule === "recording" ? Style.pillCriticalBg : Style.pillBg
                border.color: root.activeModule === "recording" ? Style.pillCriticalBorder : Style.pillBorder
                Behavior on color        { ColorAnimation { duration: Style.rollDuration; easing.type: Style.rollTranslateEasing } }
                Behavior on border.color { ColorAnimation { duration: Style.rollDuration; easing.type: Style.rollTranslateEasing } }

                // ── Persistent pill content (shown when not rolling) ───────
                Loader {
                    id: pillLoader
                    anchors.fill: parent
                    visible: !root._inTransition
                    source: root._pillSource(root.activeModule)
                    onLoaded: root._bindPill(pillLoader, root.activeModule)
                }

                // ── Roll overlay (shown only mid-transition) ────────────────
                Item {
                    anchors.fill: parent
                    visible: root._inTransition

                    // Outgoing — rolls out toward the exit edge, squashing
                    // toward that same edge as it goes.
                    Item {
                        id: outItem
                        width: parent.width
                        height: parent.height
                        y: root._rollDir > 0 ? -root._rollProgress * Style.pillHeight
                                              :  root._rollProgress * Style.pillHeight
                        opacity: 1 - root._rollProgress
                        transform: Scale {
                            yScale: 1 - root._rollScaleProgress * 0.9
                            origin.y: root._rollDir > 0 ? 0 : outItem.height
                        }

                        Loader {
                            id: outLoader
                            anchors.fill: parent
                            onLoaded: root._bindPillSnapshot(outLoader, root._outgoingModule)
                        }
                    }

                    // Incoming — rolls in from the entry edge, growing from 0
                    // as if emerging from behind that edge.
                    Item {
                        id: inItem
                        width: parent.width
                        height: parent.height
                        y: root._rollDir > 0 ? (1 - root._rollProgress) * Style.pillHeight
                                              : -(1 - root._rollProgress) * Style.pillHeight
                        opacity: root._rollProgress
                        transform: Scale {
                            yScale: 0.1 + root._rollScaleProgress * 0.9
                            origin.y: root._rollDir > 0 ? inItem.height : 0
                        }

                        Loader {
                            id: inLoader
                            anchors.fill: parent
                            onLoaded: root._bindPill(inLoader, root.activeModule)
                        }
                    }
                }
            }

            // ── Expanded panel (MPRIS player, window switcher, calendar) ───
            // Anchored directly below the now-static bar; unaffected by the
            // roll transition above — opens/closes instantly, as before.
            Loader {
                id: moduleLoader
                width: parent.width
                anchors.top: bar.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                source: root._panelSource(root.activeModule)
                onLoaded: root._bindPanel(moduleLoader, root.activeModule)
            }
        }
    }

    // Drives the roll: animates _rollProgress (translate/opacity, InOutCubic)
    // and _rollScaleProgress (squash, InOutQuad) 0→1 in parallel, from which
    // outItem/inItem's y/opacity/scale are derived.  On finish, tear down the
    // transition loaders — pillLoader (already on the new source) takes over.
    ParallelAnimation {
        id: rollAnim
        NumberAnimation {
            target: root; property: "_rollProgress"
            from: 0; to: 1
            duration: Style.rollDuration
            easing.type: Style.rollTranslateEasing
        }
        NumberAnimation {
            target: root; property: "_rollScaleProgress"
            from: 0; to: 1
            duration: Style.rollDuration
            easing.type: Style.rollScaleEasing
        }
        onFinished: {
            outLoader.source = ""
            inLoader.source  = ""
            root._inTransition = false
        }
    }

    // Fire once the combined bar+panel region has been continuously hovered
    // for 30s while that module is active, making its panel permanent until
    // dismissed (and, for MPRIS, overriding the auto-return-on-stop below).
    Timer {
        id: calendarPinTimer
        interval: 30000
        onTriggered: root._calendarPinned = true
    }
    Timer {
        id: mprisPinTimer
        interval: 30000
        onTriggered: root._mprisPinned = true
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

    // FIFO-based toggle for the calendar panel — labwc W-1 writes to this pipe.
    // Same self-kill-by-PID pattern as windowToggleReader above. Toggling on
    // forces the bar to "time" and pins the calendar open (permanent, same as
    // the 30s-hover pin); toggling off unpins it and returns to restingModule.
    Process {
        id: calendarToggleReader
        command: ["sh", "-c",
            "P=/tmp/qs-calendar-toggle-reader.pid; " +
            "if [ -f \"$P\" ]; then O=$(cat \"$P\"); pkill -P \"$O\" 2>/dev/null; kill \"$O\" 2>/dev/null; fi; " +
            "echo $$ > \"$P\"; " +
            "rm -f /tmp/qs-calendar-toggle; mkfifo /tmp/qs-calendar-toggle; " +
            "while true; do cat /tmp/qs-calendar-toggle; done"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "toggle") return
                if (root.activeModule === "time" && root._calendarPinned) {
                    root._calendarPinned = false
                    root.activeModule = root.restingModule
                } else {
                    root.activeModule = "time"
                    root._calendarPinned = true
                }
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

    // Polls gcal-fetch (helper/calendar/gcal_fetch.py) on a timer — it's a
    // one-shot script (OAuth + network round trip), not a resident daemon
    // like qs-watcher, so there's nothing to hold open between fetches.
    // On any failure it still prints valid JSON with an empty events array
    // (see gcal_fetch.py), except when another instance holds the lock —
    // then stdout is empty and JSON.parse throws, so the catch below just
    // keeps the last-known-good calendarEvents rather than clearing it.
    Process {
        id: calendarFetch
        command: ["gcal-fetch"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.calendarEvents = d.events || []
                } catch (e) {}
            }
        }
    }

    Timer {
        id: calendarFetchTimer
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: calendarFetch.running = true
    }

}
