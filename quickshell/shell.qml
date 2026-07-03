import Quickshell
import Quickshell.Wayland
import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import "components"

ShellRoot {
    id: root

    // priority: "time"=0 | "mpris"=1 | "workspace"=2 | "window"=3 | "recording"/"recordingSaved"=4
    property string currentWorkspace: "1"
    property var    workspaceList:    []
    property bool   isRecording: false
    property MprisPlayer mprisPlayer: null   // player to display (kept during 1s pause window)
    property bool   isMprisActive: false     // true only while actually playing
    property var    wallpapers: []
    property var    _wallpaperBuf: []
    property var    windows: []
    property var    calendarEvents: []
    property var    weatherData: ({})

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

    // Priority index for each module.  onActiveModuleChanged compares the old
    // and new indices to set _rollDir: new >= old → incoming rolls in from
    // below (+1), new < old → incoming rolls in from above (-1).
    readonly property var _modPriority: ({
        "time": 0, "mpris": 1, "workspace": 2, "window": 3,
        "recording": 4, "recordingSaved": 4
    })

    // ── Priority-stack arbiter ─────────────────────────────────────────────────
    // Replaces the old flat/last-write-wins activeModule register. Each active
    // requester pushes a {token, id, priority} entry; activeModule is derived
    // from whichever entry currently has the highest priority. Releasing an
    // entry falls through to whatever's next on the stack (or "time" if the
    // stack is empty) instead of always reverting to a fixed resting module —
    // this is what lets e.g. a workspace flash resume the window-switcher
    // panel afterward instead of dropping straight back to idle.
    property var _moduleStack: []   // reassigned (not mutated) so bindings fire

    readonly property var _topEntry: {
        if (root._moduleStack.length === 0) return null
        var top = root._moduleStack[0]
        for (var i = 1; i < root._moduleStack.length; i++)
            if (root._moduleStack[i].priority > top.priority) top = root._moduleStack[i]
        return top
    }
    readonly property string activeModule: root._topEntry ? root._topEntry.id : "time"

    function _requestModule(token, id, priority) {
        var next = root._moduleStack.filter(function(e) { return e.token !== token })
        next.push({ token: token, id: id, priority: priority })
        root._moduleStack = next
    }
    function _releaseModule(token) {
        root._moduleStack = root._moduleStack.filter(function(e) { return e.token !== token })
    }
    function _hasModule(token) {
        return root._moduleStack.some(function(e) { return e.token === token })
    }

    // Pin flags now also gate pill visibility (see _pillVisible below), so
    // they must route through the stack rather than being plain display flags.
    function _setCalendarPinned(v) {
        root._calendarPinned = v
        if (v) root._requestModule("calendar-pin", "time", root._modPriority["time"])
        else   root._releaseModule("calendar-pin")
    }
    function _setMprisPinned(v) {
        root._mprisPinned = v
        if (v) root._requestModule("mpris-pin", "mpris", root._modPriority["mpris"])
        else   root._releaseModule("mpris-pin")
    }

    // ── Pill show/hide ─────────────────────────────────────────────────────────
    // Hidden by default (no reserved screen space, ever — see PanelWindow's
    // exclusiveZone below); slides out whenever the stack has any content, the
    // combined bar+panel region is hovered (hot-zone reveal when idle), or a
    // future keybind forces it open (_keybindReveal stub). The bare "mpris"
    // token is excluded here — it stays on the stack for the whole song so it
    // remains the logical priority winner (see _peekMpris), but its mere
    // presence must not force the pill open; only a hover/pin actually shows
    // it. "mpris-pin" is a distinct token and still counts normally.
    readonly property bool _stackHasContent: root._moduleStack.some(function(e) { return e.token !== "mpris" })
    property bool _keybindReveal: false   // stub — future revealToggleReader FIFO flips this
    readonly property bool _pillVisible: root._stackHasContent || root._panelHovered || root._keybindReveal

    // Only allowed to retract once no roll is mid-flight — this is what
    // sequences "finish any in-flight roll, THEN hide" without any manual
    // animation chaining (see _pillOpen below). Deliberately does not require
    // activeModule === "time": mpris can sit as the topEntry for an entire
    // song while _pillVisible is false (background session, not hovered), and
    // must still be able to hide in that state.
    readonly property bool _readyToHide: !root._pillVisible && !root._inTransition

    // Target open state, as a plain binding rather than imperative onChanged
    // handlers (QML's auto-generated on<Prop>Changed name isn't reliable for
    // underscore-prefixed properties). Stays open (1) whenever visible OR
    // not yet ready to hide (mid-roll-back-to-time); only targets 0 once
    // genuinely settled and idle. _pillOpen just tracks this target, with a
    // Behavior animating the transition — this also gives the correct
    // hidden-by-default value for free at startup (nothing on the stack →
    // target is 0 from the very first evaluation, no special-casing needed).
    readonly property real _pillOpenTarget: (root._pillVisible || !root._readyToHide) ? 1.0 : 0.0
    property real _pillOpen: root._pillOpenTarget
    Behavior on _pillOpen {
        NumberAnimation { duration: Style.pillSlideDuration; easing.type: Style.pillSlideEasing }
    }

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
                root._setMprisPinned(false)
                // Re-arm the countdown if still hovering — see the "time" branch below.
                root._updatePanelPinTimer()
            })
        }
        if (mod === "time") {
            item.hovered = Qt.binding(() => root._panelHovered)
            item.pinned  = Qt.binding(() => root._calendarPinned)
            item.events  = Qt.binding(() => root.calendarEvents)
            item.weather = Qt.binding(() => root.weatherData)
            item.dismissRequested.connect(function() {
                root._setCalendarPinned(false)
                // Dismissing happens while still hovering (you just clicked a
                // button on the panel) — no hover transition occurs to restart
                // the countdown on its own, so re-arm it explicitly here.
                root._updatePanelPinTimer()
            })
        }
        if (mod === "window") {
            item.windows = Qt.binding(() => root.windows)
            item.windowFocused.connect(function() {
                root._releaseModule("window")
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

    // Keeps the "mpris" stack entry resident for as long as a track is
    // actually playing — stopping mprisTimer here (rather than restarting
    // it) is what makes mpris the persistent logical priority winner for the
    // whole song, independent of hover. A mako notification stands in for
    // the visible "peek" instead of any pill-visibility state (see
    // _notifyMprisTrack). Once playback isn't active, falls back to the old
    // deferred-release shape: release 1s after the panel stops being
    // hovered, same as every other brief-flash trigger (workspace,
    // recording). mprisPlayer/isMprisActive are maintained separately in
    // _syncMpris below, so the session persists across hides regardless.
    function _peekMpris() {
        root._requestModule("mpris", "mpris", root._modPriority["mpris"])
        if (root.isMprisActive) {
            mprisTimer.stop()
            root._notifyMprisTrack()
        } else if (!(root._panelHovered && root.activeModule === "mpris")) {
            mprisTimer.restart()
        }
    }

    // Fires (or replaces, via mako's replaces-id) a top-right desktop
    // notification announcing the current track — this is the entire
    // "peek" UX now; the bar pill itself never auto-opens on a track
    // change. Independent of activeModule/_pillVisible on purpose: it
    // should fire even when a higher-priority module (recording/window/
    // workspace) currently owns the bar.
    property int _mprisNotifyId: 0

    function _notifyMprisTrack() {
        if (!root.mprisPlayer) return
        var args = ["notify-send", "-a", "Now Playing", "-u", "low", "-p"]
        if (root._mprisNotifyId > 0) args.push("-r", String(root._mprisNotifyId))
        args.push(root.mprisPlayer.trackTitle || "", root.mprisPlayer.trackArtist || "")
        mprisNotifyProcess.command = args
        mprisNotifyProcess.running = true
    }

    Process {
        id: mprisNotifyProcess
        stdout: StdioCollector {
            onStreamFinished: {
                var id = parseInt(text.trim())
                if (!isNaN(id)) root._mprisNotifyId = id
            }
        }
    }

    // Maintains mpris session state (mprisPlayer/isMprisActive) from the live
    // player list — this is the "background session," untouched by hide/show.
    // Every call here is itself already event-driven (onPlaybackStateChanged,
    // onObjectAdded/Removed below), so peeking on every playing/paused sighting
    // is correct — it only fires on real play/pause/track transitions, not a poll.
    function _syncMpris() {
        var playing = null
        var paused  = null
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if (p.playbackState === MprisPlaybackState.Playing && !playing) playing = p
            else if (p.playbackState === MprisPlaybackState.Paused  && !paused)  paused  = p
        }
        root.isMprisActive = (playing !== null)
        if (playing !== null) {
            root.mprisPlayer = playing
            root._peekMpris()
        } else if (paused !== null) {
            root.mprisPlayer = paused
            root._peekMpris()
        } else {
            root.mprisPlayer = null   // only null when truly no players exist
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
        // Permanently 0 — the pill overlays windows rather than reserving
        // screen space, whether hidden or open (see _pillVisible/_pillOpen).
        // wlr-layer-shell's exclusiveZone is compositor space-reservation
        // accounting, not a renderable value, so it isn't animated here —
        // only the visual slide (an ordinary surface resize) is.
        exclusiveZone: 0

        // Hidden (retracted): shrinks to a thin always-present hover strip
        // (Style.hotZoneHeight) at the standard 10%-width hot-zone, so
        // there's always something to hover to reveal the pill. Visible:
        // grows/shrinks continuously with _pillOpen as it slides in/out.
        implicitWidth: root._pillVisible
            ? Math.round(Screen.width * root._panelWidthFrac(root.activeModule))
            : Math.round(Screen.width * 0.10)
        implicitHeight: Style.hotZoneHeight + root._pillOpen * (Style.pillHeight + moduleLoader.implicitHeight)

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
                    root._releaseModule("window")
                    event.accepted = true
                } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.MetaModifier)) {
                    root._releaseModule("window")
                    event.accepted = true
                }
            }

            // Tracks the mouse over the combined bar+panel region — this Item's
            // bounds already equal Style.pillHeight + moduleLoader.implicitHeight
            // (it fills the PanelWindow, which is sized to exactly that), so this
            // naturally grows to cover a panel the moment it opens. Only consumed
            // when the active module actually has a hover-based panel (time,
            // mpris); harmless no-op otherwise. When the pill is retracted, this
            // is the only thing live over the thin hot-zone strip — hovering it
            // sets _panelHovered, which is one of _pillVisible's OR-clauses, so
            // reveal falls out for free with no separate hot-zone element.
            HoverHandler {
                onHoveredChanged: {
                    root._panelHovered = hovered
                    root._updatePanelPinTimer()
                    // MPRIS release is gated on playback actually having
                    // stopped/paused, not just on you glancing away — while
                    // isMprisActive is true the token stays resident for the
                    // whole song (see _peekMpris) regardless of hover.
                    if (!hovered && root.activeModule === "mpris" && !root._mprisPinned && !root.isMprisActive)
                        mprisTimer.restart()
                }
            }

            // Wraps the bar + panel and translates them off the top edge as
            // _pillOpen goes 1→0, so retracting slides everything up behind
            // the clip boundary instead of just popping invisible. Only
            // begins once _readyToHide allows it (any in-flight roll has
            // settled — see its declaration above), so the sequence is
            // always "finish rolling, then slide away," never both at once.
            Item {
                id: pillContent
                width: parent.width
                height: Style.pillHeight + moduleLoader.implicitHeight
                y: -(Style.pillHeight + moduleLoader.implicitHeight) * (1 - root._pillOpen)

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
        onTriggered: root._setCalendarPinned(true)
    }
    Timer {
        id: mprisPinTimer
        interval: 30000
        onTriggered: root._setMprisPinned(true)
    }

    // Release the workspace-flash stack entry — falls through to whatever's
    // next on the stack (or "time" if nothing else is queued), rather than a
    // fixed resting module. Releasing an absent token is a no-op, so the old
    // "am I still on workspace" guard is no longer needed.
    Timer {
        id: workspaceTimer
        interval: 1000
        onTriggered: root._releaseModule("workspace")
    }

    // Release the "RECORDING SAVED" flash entry after it's shown briefly.
    Timer {
        id: recordingTimer
        interval: 1000
        onTriggered: root._releaseModule("recording")
    }

    // Release the MPRIS peek entry 1s after a play/pause/track-change event.
    // mprisPlayer/isMprisActive are deliberately left untouched here — the
    // player session persists in the background even once the pill hides,
    // so a future on-demand "show mpris" call can reveal it again without
    // re-deriving anything (see _syncMpris/_peekMpris).
    Timer {
        id: mprisTimer
        interval: 1000
        onTriggered: root._releaseModule("mpris")
    }

    // Watch each player's playback state (and track changes) reactively
    Instantiator {
        model: Mpris.players
        delegate: QtObject {
            required property var modelData
            property var _conn: Connections {
                target: modelData
                function onPlaybackStateChanged() { root._syncMpris() }
                // Track changes while already playing don't flip playbackState,
                // so they wouldn't otherwise re-trigger a peek — this is what
                // makes a new track its own "call," per the confirmed MPRIS
                // peek-on-event behavior.
                function onTrackChanged() { root._syncMpris() }
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
                // Priority 4 always wins the stack top regardless of what's
                // underneath, so there's no need to stop workspace/recording
                // timers anymore — releasing "recording" later just falls
                // through to whatever's still queued.
                root._requestModule("recording", "recording", 4)
            } else if (!nowRecording && root.isRecording) {
                root.isRecording = false
                root._requestModule("recording", "recordingSaved", 4)
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
                if (root._hasModule("window"))
                    root._releaseModule("window")
                else
                    root._requestModule("window", "window", 3)
            }
        }
    }

    // FIFO-based toggle for the calendar panel — labwc W-1 writes to this pipe.
    // Same self-kill-by-PID pattern as windowToggleReader above. Toggling on
    // pins the calendar open (permanent, same as the 30s-hover pin, backed by
    // a stack entry so the pill stays visible); toggling off unpins it.
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
                if (root._calendarPinned) root._setCalendarPinned(false)
                else                      root._setCalendarPinned(true)
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
                            root._requestModule("workspace", "workspace", 2)
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
        interval: Style.calendarFetchIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: calendarFetch.running = true
    }

    // Polls weather-fetch (helper/weather/weather_fetch.py) on a timer — same
    // one-shot-process shape as gcal-fetch above. It always prints valid JSON
    // (nulls on failure, see weather_fetch.py), so a parse failure here only
    // happens if another instance holds stdout mid-write; the catch below
    // just keeps the last-known-good weatherData rather than clearing it.
    Process {
        id: weatherFetch
        command: ["weather-fetch"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.weatherData = JSON.parse(text)
                } catch (e) {}
            }
        }
    }

    Timer {
        id: weatherFetchTimer
        interval: Style.weatherFetchIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherFetch.running = true
    }

}
