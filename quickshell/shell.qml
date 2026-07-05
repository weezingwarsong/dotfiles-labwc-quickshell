import Quickshell
import QtQuick
import "./root-processes"
import "./module-pills"
import "./module-panels"
import "./module-reusable-elements"

ShellRoot {
    id: root

    FifoListener {
        id: fifo

        onShowTimeRequested:         controller.triggerPeek()
        onRefreshCalendarRequested:  calendar.refresh()
        onToggleCalendarRequested:   panelController.toggle("calendar")
        onTimerSet:                  function(secs) { timer.setTimer(secs) }
        onTimerStartRequested:       timer.startTimer()
        onTimerPauseRequested:       timer.pauseTimer()
        onTimerResetRequested:       timer.resetTimer()
        onStopwatchStartRequested:   timer.startStopwatch()
        onStopwatchStopRequested:    timer.stopStopwatch()
        onStopwatchResetRequested:   timer.resetStopwatch()
    }

    ClockProcess      { id: clock }
    CalendarProcess   { id: calendar }
    TasksProcess      { id: tasks }
    TimerProcess      { id: timer }
    WeatherProcess    { id: weather }
    WorkspaceProcess  { id: workspace }

    TimePill {
        id: timePill
        clockProcess:    clock
        calendarProcess: calendar
        timerProcess:    timer
    }

    WorkspacePill {
        id: workspacePill
        workspaceProcess: workspace
    }

    HoverZone { id: hoverZone }

    PillController {
        id: controller
        hovered:       hoverZone.hovered
        timePill:      timePill
        workspacePill: workspacePill
    }

    PillWindow {
        activePill: controller.activePill
        shouldShow: controller.shouldShow
    }

    PanelController {
        id: panelController
    }

    PanelSurface {
        activePanel:     panelController.activePanel
        shouldShow:      panelController.shouldShow
        clockProcess:    clock
        calendarProcess: calendar
        tasksProcess:    tasks
        weatherProcess:  weather
        timerProcess:    timer
    }
}

/*
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
    // `_rawPanelHovered` tracks the mouse over the combined bar+panel region
    // (see the HoverHandler below) — not just the bar itself — so moving from
    // the pill down into its panel doesn't count as leaving. `_panelHovered`
    // (below, near _animating) is the gated value everything else reads —
    // hovering in is suppressed while a roll/slide is mid-flight (spawning
    // the expanded panel mid-animation looked broken), but hovering back OUT
    // is never gated, so nothing can get stuck open. The `*Pinned` flags
    // live here (not on the Calendar.qml/MediaPlayer.qml panel instances) so they survive
    // the panel being destroyed/recreated during brief interruptions (workspace
    // flash, recording) while that module isn't the active one.
    property bool _rawPanelHovered: false
    property bool _calendarPinned: false
    property bool _mprisPinned: false

    // Set by the dedicated `hotZone` PanelWindow (a separate, never-resizing
    // surface above the pill) — reveal-only, see _pillVisible below for why
    // it's kept apart from _panelHovered.
    property bool _hotZoneHovered: false

    // ── Transition state ──────────────────────────────────────────────────────
    property string _prevModule: ""
    property string _outgoingModule: ""
    property bool   _inTransition: false

    // ── Panel identity (decoupled from which pill is active) ─────────────────
    // Which panel (if any) belongs to each pill — a static fact about the
    // pill, not something that varies per request, so this is the only place
    // the pill→panel parent/child link needs to live. _panelSource/_bindPanel/
    // _panelWidthFrac below key off a *panel* id from this map, never a pill
    // id directly, so a panel can only ever be reached by first going through
    // its one parent pill.
    readonly property var _panelForPill: ({ "time": "calendar", "mpris": "mediaPlayer", "window": "windowSwitcher" })
    // The panel the current winning pill wants shown. A plain function, not a
    // `readonly property` binding — a property binding on
    // `_panelForPill[root.activeModule]` was observed to freeze at its
    // Component.onCompleted value and never re-evaluate on later
    // activeModule changes (QML's dependency tracking didn't pick up the
    // bracket-indexed read), so this is called fresh at every use site
    // instead of cached. _displayedPanel (below) is what's actually bound to
    // moduleLoader — see the panelStillClosing branch in onActiveModuleChanged
    // for why the two are allowed to diverge briefly on the way out.
    function _topPanel() {
        return root._panelForPill[root.activeModule] || ""
    }
    property string _displayedPanel: ""
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

    // Priority tier for an explicit "force this panel open" keybind (W-1
    // calendar today; a future mpris-open keybind, etc.) — always above every
    // passive/ambient module, including recording, since pressing the keybind
    // is a deliberate, one-off request that should always win. See
    // _setCalendarPinned/_setMprisPinned for the accompanying mutual-exclusion
    // ("latest keybind wins") — this constant alone only handles ranking
    // above the rest of the stack, not exclusivity between pins themselves.
    readonly property int _forcedPinPriority: 5

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
    // Pinning is mutually exclusive across panels — standardized so any
    // future "force panel open" keybind follows the same rule: turning one
    // pin on dismisses whichever other panel was pinned/active, and its stack
    // entry sits at _forcedPinPriority (always above mpris/workspace/window/
    // recording), so "the latest keybind wins," full stop. Window switcher is
    // part of the same group even though it has no separate "pinned" flag of
    // its own (there's nothing to leave on across sessions to track) — W-Tab
    // is just as much an explicit "force this open" request as W-1/W-2.
    function _setCalendarPinned(v) {
        root._calendarPinned = v
        if (v) {
            if (root._mprisPinned)         root._setMprisPinned(false)
            if (root._hasModule("window")) root._setWindowActive(false)
            root._requestModule("calendar-pin", "time", root._forcedPinPriority)
        } else {
            root._releaseModule("calendar-pin")
        }
    }
    function _setMprisPinned(v) {
        root._mprisPinned = v
        if (v) {
            if (root._calendarPinned)      root._setCalendarPinned(false)
            if (root._hasModule("window")) root._setWindowActive(false)
            root._requestModule("mpris-pin", "mpris", root._forcedPinPriority)
        } else {
            root._releaseModule("mpris-pin")
        }
    }
    function _setWindowActive(v) {
        if (v) {
            if (root._calendarPinned) root._setCalendarPinned(false)
            if (root._mprisPinned)    root._setMprisPinned(false)
            root._requestModule("window", "window", root._forcedPinPriority)
        } else {
            root._releaseModule("window")
        }
    }

    // ── Escape-to-dismiss / keyboard focus grab ───────────────────────────────
    // Centralized here (not per-panel-component — see the `panel` PanelWindow
    // below) since there's only one physical layer-shell surface hosting
    // whichever module is active, and dismissing needs direct access to the
    // arbiter/pin state above anyway. A table instead of if/else per module so
    // adding a future panel is a one-line addition here, not three separate
    // branches. "window" wants focus unconditionally (it's inherently modal —
    // you're actively driving it via keyboard); the hover-panels only once
    // explicitly pinned, so a passive hover-peek never steals keyboard input
    // from whatever app you're actually using.
    readonly property var _keyboardGrabModules: ({
        "window": { wants: function() { return true }, dismiss: function() { root._setWindowActive(false) } },
        "time":   { wants: function() { return root._calendarPinned }, dismiss: function() { root._setCalendarPinned(false); root._updatePanelPinTimer() } },
        "mpris":  { wants: function() { return root._mprisPinned },    dismiss: function() { root._setMprisPinned(false);    root._updatePanelPinTimer() } }
    })
    readonly property bool _wantsKeyboardFocus: {
        var entry = root._keyboardGrabModules[root.activeModule]
        return entry ? entry.wants() : false
    }
    function _dismissActivePanel() {
        var entry = root._keyboardGrabModules[root.activeModule]
        if (entry) entry.dismiss()
    }

    // ── Pill show/hide ─────────────────────────────────────────────────────────
    // Hidden by default (no reserved screen space, ever — see PanelWindow's
    // exclusiveZone below); slides out whenever the stack has any content, the
    // dedicated `hotZone` strip is hovered while idle, the pill+panel itself
    // is hovered once visible, or a future keybind forces it open
    // (_keybindReveal stub). The bare "mpris" token is excluded here — it
    // stays on the stack for the whole song so it remains the logical
    // priority winner (see _peekMpris), but its mere presence must not force
    // the pill open on its own; only a hover/pin actually shows it, and the
    // track-change "peek" is a desktop notification instead (see
    // _notifyMprisTrack). "mpris-pin" is a distinct token and still counts.
    readonly property bool _stackHasContent: root._moduleStack.some(function(e) { return e.token !== "mpris" })
    property bool _keybindReveal: false   // stub — future revealToggleReader FIFO flips this
    // _hotZoneHovered (dedicated static strip, see the `hotZone` PanelWindow
    // below) only ever asks to reveal the pill. _panelHovered (the pill+panel
    // surface itself) is what also opens the module's own panel — see
    // _bindPanel. Keeping these separate is what stops "the pill appeared
    // under my resting cursor because I hovered the strip above it" from
    // also popping the calendar/mpris panel open uninvited.
    readonly property bool _pillVisible: root._stackHasContent || root._panelHovered || root._hotZoneHovered || root._keybindReveal

    // True while either half of the reveal/exit sequence (roll or slide) is
    // actively animating — see _inTransition/rollAnim further down for the
    // roll half. The slide half is checked as _pillOpen !== _pillOpenTarget
    // (a plain value comparison) rather than the Behavior's animation
    // .running flag — the two can otherwise have a one-tick gap right at the
    // roll→slide handoff (_inTransition just went false, but the Behavior
    // hasn't started animating _pillOpen towards its new target yet), and a
    // hover landing in that gap was still slipping through during exit. The
    // value comparison has no such gap: _pillOpenTarget updates synchronously
    // with _inTransition, so it's already unequal to _pillOpen the instant
    // the target changes, before the Behavior even starts. Used only to gate
    // _panelHovered (below): hovering in while the pill/panel is still
    // resizing or rolling used to spawn the expanded panel mid-motion, which
    // looked broken; gating just the "hover in" edge means the instant the
    // animation settles, _panelHovered reevaluates on its own (no manual
    // re-check needed) if the mouse is still there.
    readonly property bool _animating: root._inTransition || root._pillOpen !== root._pillOpenTarget

    // The gated value everything else reads. _rawPanelHovered flips instantly
    // on both hover-in and hover-out (see the HoverHandler below); ANDing
    // with !_animating only suppresses the hover-*in* edge while animating —
    // hover-out (_rawPanelHovered already false) is untouched, so nothing can
    // get stuck open waiting for an animation that already finished.
    readonly property bool _panelHovered: root._rawPanelHovered && !root._animating

    // Only allowed to retract once no roll is mid-flight AND the panel has
    // finished its own shrink (_panelOpen below) — this is what sequences
    // "finish any in-flight roll and panel-shrink, THEN hide" without any
    // manual animation chaining (see _pillOpen below). Deliberately does not
    // require activeModule === "time": mpris can sit as the topEntry for an
    // entire song while _pillVisible is false (background session, not
    // hovered), and must still be able to hide in that state.
    readonly property bool _readyToHide: !root._pillVisible && !root._inTransition && root._panelOpen === 0

    // Target open state, as a plain binding rather than imperative onChanged
    // handlers (QML's auto-generated on<Prop>Changed name isn't reliable for
    // underscore-prefixed properties). Stays open (1) whenever visible OR
    // not yet ready to hide (mid-roll-back-to-time); only targets 0 once
    // genuinely settled and idle. _pillOpen just tracks this target, with a
    // Behavior animating the transition — this also gives the correct
    // hidden-by-default value for free at startup (nothing on the stack →
    // target is 0 from the very first evaluation, no special-casing needed).
    // Easing is reactive rather than a fixed Style constant: OutQuad (fast
    // start, decelerating) entering, InQuad (slow start, accelerating)
    // exiting — see the matching choice on _panelOpen and rollAnim below,
    // all three stages of the same enter/exit sequence share this pair.
    readonly property real _pillOpenTarget: (root._pillVisible || !root._readyToHide) ? 1.0 : 0.0
    property real _pillOpen: root._pillOpenTarget
    Behavior on _pillOpen {
        NumberAnimation {
            duration: Style.pillSlideDuration
            easing.type: root._pillOpenTarget ? Easing.OutQuad : Easing.InQuad
        }
    }

    // Drives the expanded panel's own grow/shrink (see panelClip below), the
    // last of three strictly sequential 50ms stages — see Style.qml's
    // Animation section for the full Pill→Text→Panel (enter) / Panel→Text→
    // Pill (exit) picture:
    //   - Enter: target only goes true once _pillOpen has reached 1 AND the
    //     roll has finished (!_inTransition) — using _pillOpen rather than
    //     _pillVisible/_pillOpenTarget is what makes this wait for the
    //     slide's last animated frame, not just its start; requiring
    //     !_inTransition too is what pushes the panel behind the text stage
    //     instead of running alongside it.
    //   - Exit: target goes false the instant _pillVisible does, immediately
    //     — before the roll (_inTransition) even reacts to the same
    //     intent-to-close, since the panel must be the very first thing to
    //     move on the way out. onActiveModuleChanged (below) is what then
    //     delays the roll until this finishes, and _readyToHide gates the
    //     pill-slide on both the roll and this being done, in that order.
    readonly property bool _panelOpenTarget: root._pillVisible && root._pillOpen === 1 && !root._inTransition
    property real _panelOpen: root._panelOpenTarget ? 1.0 : 0.0
    Behavior on _panelOpen {
        NumberAnimation {
            duration: Style.pillSlideDuration
            easing.type: root._panelOpenTarget ? Easing.OutQuad : Easing.InQuad
        }
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

    // The expanded panel anchored below the bar, keyed by *panel* id (see
    // _panelForPill above) — never by pill/module id directly. Workspace/
    // recording have no entry in _panelForPill, so this returns "" for them.
    function _panelSource(panelId) {
        if (panelId === "mediaPlayer")    return Qt.resolvedUrl("components/MediaPlayer.qml")
        if (panelId === "windowSwitcher") return Qt.resolvedUrl("components/WindowSwitcher.qml")
        if (panelId === "calendar")       return Qt.resolvedUrl("components/Calendar.qml")
        return ""
    }

    // Fraction of screen width for the panel *window* (bar + its panel).
    // The bar itself stays a fixed small pill regardless (see `bar.width` in
    // the PanelWindow below) — only the panel content area below it grows.
    // All panels currently share the same narrow width (calendar used to be
    // a wide dashboard layout, now stacked vertically to match the pill) —
    // kept as a per-panel function so a future wide panel (e.g. Settings)
    // can override it without touching the panel-window plumbing.
    function _panelWidthFrac(panelId) {
        return panelId === "calendar" ? 0.10 : 0.10
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

    // Bind the expanded panel below the bar, keyed by *panel* id (see
    // _panelForPill above). Calendar's and the media player's `hovered`/
    // `pinned` both come from the root-level combined-region hover and pin
    // state (see _panelHovered above), since each panel's hover area spans
    // pill+gap+panel, not just the pill.
    function _bindPanel(loader, panelId) {
        var item = loader.item
        if (!item) return
        if (panelId === "mediaPlayer") {
            item.hovered = Qt.binding(() => root._panelHovered)
            item.pinned  = Qt.binding(() => root._mprisPinned)
            item.player  = Qt.binding(() => root.mprisPlayer)
            item.dismissRequested.connect(function() {
                root._setMprisPinned(false)
                // Re-arm the countdown if still hovering — see the "calendar" branch below.
                root._updatePanelPinTimer()
            })
        }
        if (panelId === "calendar") {
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
        if (panelId === "windowSwitcher") {
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
        root._displayedPanel = root._topPanel()
    }

    // Transition sequencing:
    //   1. Capture outgoing pill source (from the module we're leaving) into outLoader.
    //   2. Load the incoming pill source into inLoader so both can animate simultaneously.
    //   3. rollAnim drives _rollProgress/_rollScaleProgress 0→1; slot y/opacity/scale derive from them.
    //   4. rollAnim.onFinished tears down the transition loaders.
    // pillLoader.source is a plain binding on activeModule (declared where it's
    // used below) — it updates immediately, but pillLoader stays invisible
    // (visible: !_inTransition) until the roll finishes, so there's no premature
    // flash of the new content. moduleLoader.source instead follows the lagged
    // _displayedPanel (see panelSwapDelay below), not activeModule directly —
    // it only swaps once any outgoing panel has actually finished shrinking.
    //
    // Enter/exit vs. steady-state swap: on enter, _pillOpen < 1 means the
    // container itself hasn't finished growing yet (possibly just starting
    // this same tick) — the roll is delayed until that finishes
    // (rollStartDelay, timed to pillSlideDuration), giving Pill→Text→Panel.
    // On exit, _panelOpen > 0 && !_panelOpenTarget means the panel is still
    // (or about to start) shrinking — the roll is equally delayed until
    // *that* finishes instead, giving Panel→Text→Pill. If neither is true,
    // the container isn't moving at all (a plain in-place module swap, e.g.
    // recording preempting mpris while both are visible), so the roll starts
    // immediately, same as always. Either delayed case, the reverse-direction
    // partner needs no equivalent delay of its own here — _readyToHide's
    // `!_inTransition` already blocks the pill-slide from starting until the
    // roll has finished, and _panelOpenTarget's own `!_inTransition` already
    // blocks the panel-grow the same way on enter.
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

        // Checked before flipping _inTransition below: _panelOpenTarget itself
        // depends on !_inTransition (see its declaration), so evaluating it
        // after that flip would always read false here and over-delay even
        // the steady-state case. !_pillVisible is the stable, direct signal
        // for "we're on our way out" instead.
        var panelStillClosing = root._panelOpen > 0 && !root._pillVisible
        var pillStillOpening  = root._pillOpen < 1

        // Same panelStillClosing signal also decides when moduleLoader is
        // allowed to swap to the new winner's panel: if a panel was actually
        // visible and nothing's queued behind it, hold the outgoing panel's
        // own content on screen until its shrink finishes (panelSwapDelay),
        // instead of swapping instantly underneath a still-open container —
        // that instant swap was the "wrong panel flashes on exit" bug.
        if (panelStillClosing) {
            panelSwapDelay.restart()
        } else {
            root._displayedPanel = root._topPanel()
        }

        root._inTransition = true
        root._rollProgress = 0
        root._rollScaleProgress = 0
        if (pillStillOpening || panelStillClosing) {
            rollStartDelay.restart()
        } else {
            rollAnim.restart()
        }

        root._updatePanelPinTimer()
    }

    // Fires the roll only after whichever neighboring stage it's waiting on
    // has settled — the pill-slide on enter, or the panel-shrink on exit —
    // see onActiveModuleChanged above. Both happen to share this same
    // duration, which is what makes one Timer/interval work for either.
    // restart()ing (rather than letting a stale one fire) if another module
    // change lands before this ticks.
    Timer {
        id: rollStartDelay
        interval: Style.pillSlideDuration
        onTriggered: rollAnim.restart()
    }

    // Swaps moduleLoader over to whatever panel the new winning pill owns,
    // but only once the outgoing panel's own shrink (panelStillClosing, in
    // onActiveModuleChanged above) has had time to finish — same duration as
    // the shrink itself, so the swap lands exactly as it visually reaches 0.
    Timer {
        id: panelSwapDelay
        interval: Style.pillSlideDuration
        onTriggered: root._displayedPanel = root._topPanel()
    }

    // Keeps the "mpris" stack entry resident for as long as a track is
    // actually playing — stopping mprisTimer here (rather than restarting
    // it) is what makes mpris the persistent logical priority winner for the
    // whole song, independent of hover. A desktop notification stands in for
    // the visible "peek" instead of any pill-visibility state (see
    // _notifyMprisTrack) — it fires regardless of whatever the bar is
    // currently showing, so a peek is never stolen by a higher-priority
    // module (recording/window/workspace). Once playback isn't active, falls
    // back to the old deferred-release shape: release 1s after the panel
    // stops being hovered, same as every other brief-flash trigger
    // (workspace, recording). mprisPlayer/isMprisActive are maintained
    // separately in _syncMpris below, so the session persists across hides
    // regardless. This is also the hook a future on-demand "show mpris"
    // keybind would call directly.
    function _peekMpris() {
        root._requestModule("mpris", "mpris", root._modPriority["mpris"])
        if (root.isMprisActive) {
            mprisTimer.stop()
            root._notifyMprisTrack()
        } else if (!(root._panelHovered && root.activeModule === "mpris")) {
            mprisTimer.restart()
        }
    }

    // Fires (or replaces, via notify-send's -r/replaces-id) a desktop
    // notification announcing the current track — this is the entire "peek"
    // UX now; the bar pill itself never auto-opens on a track change.
    // Independent of activeModule/_pillVisible on purpose: it should fire
    // even when a higher-priority module (recording/window/workspace)
    // currently owns the bar. No explicit -t: left at mako's configured
    // urgency=low default-timeout (3s).
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
    // onObjectAdded/Removed below); _peekMpris (above) is what decides
    // whether that keeps "mpris" resident or arms its dismiss countdown.
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
            if (root._hasModule("mpris")) root._peekMpris()
        }
    }

    readonly property url currentWallpaper: {
        var idx = root.workspaceList.indexOf(root.currentWorkspace)
        if (idx >= 0 && idx < wallpapers.length)
            return "file://" + wallpapers[idx]
        return ""
    }

    // Disabled while we work on the yin integration — flip back on once
    // that's wired up. Loader keeps WallpaperWindow's own surface from ever
    // being created while off, rather than just hiding it.
    property bool _wallpaperEnabled: false
    Loader {
        active: root._wallpaperEnabled
        sourceComponent: WallpaperWindow {
            source: root.currentWallpaper
        }
    }

    // ── Hot zone: dedicated, always-present hover-to-reveal strip ──────────────
    // A separate surface that never resizes — its only job is setting
    // _hotZoneHovered, which is reveal-only (see _pillVisible). Deliberately
    // NOT the same surface as `panel` below: that one also drives the
    // module's own expanded panel (calendar/mpris) via _panelHovered, and
    // fusing the two meant a passive reveal (MPRIS starting playback, a
    // workspace flash, Super+1) with the cursor already resting over the
    // pill's footprint would instantly pop that panel open too — geometry
    // masquerading as intent. Splitting them means "the pill became
    // visible" and "the user is deliberately hovering it" can't be
    // conflated. This also fixed a real flicker bug: `panel` below used to
    // double as its own hot zone, so its size depended on its own hover
    // state — hovering it could shift its edge under a jittery cursor,
    // re-triggering hover, restarting the slide, repeat. This strip never
    // resizes, so there's nothing for it to feed back into. It sits flush
    // against `panel`'s top margin (both keyed to Style.hotZoneHeight) so
    // there's no dead pixel row between them, and the pill's resting
    // position on screen is unchanged.
    PanelWindow {
        id: hotZone
        anchors.top: true
        color: "transparent"
        exclusiveZone: 0
        implicitWidth: Math.round(Screen.width * Style.hotZoneWidthFrac)
        implicitHeight: Style.hotZoneHeight

        // Same debounce as `panel`'s HoverHandler below, and needed even
        // more here: this strip is only Style.hotZoneHeight (4px) tall, an
        // easy boundary to jitter across, and _hotZoneHovered feeds
        // _pillVisible with nothing else smoothing it — undebounced, that
        // jitter flips _pillOpenTarget faster than its 300ms Behavior can
        // finish, so the slide never completes a sweep, just creeps back
        // and forth. That's what showed up as "slow motion" on reveal.
        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    _hotZoneLeaveGrace.stop()
                    root._hotZoneHovered = true
                } else {
                    _hotZoneLeaveGrace.restart()
                }
            }
        }
        Timer {
            id: _hotZoneLeaveGrace
            interval: 120
            onTriggered: root._hotZoneHovered = false
        }
    }

    PanelWindow {
        id: panel
        anchors.top: true
        color: "transparent"
        margins.top: Style.hotZoneHeight
        // Permanently 0 — the pill overlays windows rather than reserving
        // screen space, whether hidden or open (see _pillVisible/_pillOpen).
        // wlr-layer-shell's exclusiveZone is compositor space-reservation
        // accounting, not a renderable value, so it isn't animated here —
        // only the visual slide (an ordinary surface resize) is.
        exclusiveZone: 0

        // Hidden (retracted): collapses fully — the hotZone window above is
        // now the only thing that needs to be hoverable while idle. Visible:
        // grows/shrinks continuously with _pillOpen as it slides in/out.
        implicitWidth: root._pillVisible
            ? Math.round(Screen.width * root._panelWidthFrac(root._displayedPanel))
            : Math.round(Screen.width * 0.10)
        implicitHeight: root._pillOpen * (Style.pillHeight + panelClip.height)

        // Exclusive keyboard focus (a per-surface wlr-layer-shell grab, not a
        // labwc keybind) whenever the active module wants it — see
        // _wantsKeyboardFocus/_keyboardGrabModules above for which modules and
        // why (window always; hover-panels only once explicitly pinned).
        WlrLayershell.keyboardFocus: root._wantsKeyboardFocus
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        Item {
            anchors.fill: parent
            clip: true
            focus: root._wantsKeyboardFocus

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root._dismissActivePanel()
                    event.accepted = true
                } else if (root.activeModule === "window" && event.key === Qt.Key_Tab && (event.modifiers & Qt.MetaModifier)) {
                    root._releaseModule("window")
                    event.accepted = true
                }
            }

            // Tracks the mouse over the combined bar+panel region — this Item's
            // bounds already equal Style.pillHeight + panelClip.height
            // (it fills the PanelWindow, which is sized to exactly that), so this
            // naturally grows to cover a panel the moment it opens. Only consumed
            // when the active module actually has a hover-based panel (time,
            // mpris); harmless no-op otherwise. When the pill is retracted, this
            // is the only thing live over the thin hot-zone strip — hovering it
            // sets _panelHovered, which is one of _pillVisible's OR-clauses, so
            // reveal falls out for free with no separate hot-zone element.
            HoverHandler {
                onHoveredChanged: {
                    if (hovered) {
                        // Cancel any pending "leave" from a moment ago — see
                        // _hoverLeaveGrace below.
                        _hoverLeaveGrace.stop()
                        root._rawPanelHovered = true
                        root._updatePanelPinTimer()
                    } else {
                        // Debounced rather than applied immediately: the
                        // hoverable surface starts a couple px below the
                        // real screen edge (PanelWindow's margins.top, the
                        // deliberate gap above the pill), so a cursor
                        // resting right at that boundary flickers in/out of
                        // "hovered" by a pixel or two. Applying every flip
                        // immediately used to restart the pill's slide
                        // Behavior on each one, which is what showed up as
                        // flicker/stutter right at the top edge. The grace
                        // timer absorbs that jitter — a genuine mouse-away
                        // still reads as unhovered, just ~120ms later.
                        _hoverLeaveGrace.restart()
                    }
                    // MPRIS release is gated on playback actually having
                    // stopped/paused, not just on you glancing away — while
                    // isMprisActive is true the token stays resident for the
                    // whole song (see _peekMpris) regardless of hover.
                    if (!hovered && root.activeModule === "mpris" && !root._mprisPinned && !root.isMprisActive)
                        mprisTimer.restart()
                }
            }
            Timer {
                id: _hoverLeaveGrace
                interval: 120
                onTriggered: {
                    root._rawPanelHovered = false
                    root._updatePanelPinTimer()
                }
            }

            // Wraps the bar + panel and translates them off the top edge as
            // _pillOpen goes 1→0, so retracting slides everything up behind
            // the clip boundary instead of just popping invisible. Only
            // begins once _readyToHide allows it (content already settled
            // on "time", and the panel already shrunk — see its declaration
            // above), so the sequence is always "roll + panel-shrink, then
            // slide away," never overlapping the bar's own slide.
            Item {
                id: pillContent
                width: parent.width
                height: Style.pillHeight + panelClip.height
                y: -(Style.pillHeight + panelClip.height) * (1 - root._pillOpen)

                // ── Bar: a rigid rectangle that never moves or resizes. Content
                // rolls vertically inside it between modules, as if printed on a
                // cylinder rotating behind the bar's clipped window. ─────────────
                Rectangle {
                    id: bar
                    // Fixed to the narrow width regardless of which module is
                    // active — only the panel window itself (and moduleLoader
                    // below) would grow for a future wide panel (e.g. Settings).
                    // Without this, the always-visible pill would stretch to match.
                    width: Math.round(Screen.width * 0.10)
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: Style.pillHeight
                    clip: true
                    radius: Style.pillRadius
                    border.width: Style.pillBorderWidth
                    color: root.activeModule === "recording" ? Style.pillCriticalBg : Style.pillBg
                    border.color: root.activeModule === "recording" ? Style.pillCriticalBorder : Style.pillBorder
                    // Unrelated to the pill/text/panel enter-exit sequence above —
                    // just a plain crossfade into/out of the recording-red state,
                    // so it keeps its own fixed easing rather than the reactive
                    // OutQuad/InQuad pair those three stages share.
                    Behavior on color        { ColorAnimation { duration: Style.rollDuration; easing.type: Easing.InOutCubic } }
                    Behavior on border.color { ColorAnimation { duration: Style.rollDuration; easing.type: Easing.InOutCubic } }

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
                // Anchored directly below the now-static bar. moduleLoader
                // itself always stays loaded (so its natural implicitHeight is
                // known and stable) — panelClip is what's actually animated,
                // clipping it down to root._panelOpen's fraction of that
                // natural height, using the exact same 0-100ms/100-200ms
                // windows as the bar's own roll/slide (see _panelOpen above).
                Item {
                    id: panelClip
                    width: parent.width
                    anchors.top: bar.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: root._panelOpen * moduleLoader.implicitHeight
                    clip: true

                    Loader {
                        id: moduleLoader
                        width: parent.width
                        source: root._panelSource(root._displayedPanel)
                        onLoaded: root._bindPanel(moduleLoader, root._displayedPanel)
                    }
                }
            }
        }
    }

    // Drives the roll: animates _rollProgress (translate/opacity) and
    // _rollScaleProgress (squash) 0→1 in parallel, from which outItem/inItem's
    // y/opacity/scale are derived. Easing is reactive rather than a fixed
    // Style constant, matching _pillOpen/_panelOpen: OutQuad entering,
    // InQuad exiting. root._pillVisible is the signal for which — it's the
    // stable "do we want this open" intent, unlike _pillOpenTarget/
    // _panelOpenTarget which stay pinned at their "still open" value for the
    // full duration of whichever neighboring stage this roll is sequenced
    // behind, so checking those here wouldn't reliably tell enter from exit.
    // On finish, tear down the transition loaders — pillLoader (already on
    // the new source) takes over.
    ParallelAnimation {
        id: rollAnim
        NumberAnimation {
            target: root; property: "_rollProgress"
            from: 0; to: 1
            duration: Style.rollDuration
            easing.type: root._pillVisible ? Easing.OutQuad : Easing.InQuad
        }
        NumberAnimation {
            target: root; property: "_rollScaleProgress"
            from: 0; to: 1
            duration: Style.rollDuration
            easing.type: root._pillVisible ? Easing.OutQuad : Easing.InQuad
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
    // Routes through _setWindowActive (same forced-priority + mutual-exclusion
    // treatment as W-1/W-2 — see its declaration above) rather than requesting
    // the stack entry directly.
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
                    root._setWindowActive(false)
                else
                    root._setWindowActive(true)
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

    // FIFO-based toggle for the MPRIS panel — labwc W-2 writes to this pipe.
    // Same self-kill-by-PID pattern as windowToggleReader/calendarToggleReader
    // above. Toggling on pins mpris open (permanent, same as the 30s-hover
    // pin or the "still playing" background session — see _setMprisPinned,
    // which already handles mutual exclusion with calendar-pin and priority);
    // toggling off unpins it.
    Process {
        id: mprisToggleReader
        command: ["sh", "-c",
            "P=/tmp/qs-mpris-toggle-reader.pid; " +
            "if [ -f \"$P\" ]; then O=$(cat \"$P\"); pkill -P \"$O\" 2>/dev/null; kill \"$O\" 2>/dev/null; fi; " +
            "echo $$ > \"$P\"; " +
            "rm -f /tmp/qs-mpris-toggle; mkfifo /tmp/qs-mpris-toggle; " +
            "while true; do cat /tmp/qs-mpris-toggle; done"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "toggle") return
                if (root._mprisPinned) root._setMprisPinned(false)
                else                   root._setMprisPinned(true)
            }
        }
    }

    // qs-watcher is spawned directly so there are no orphaned FIFO readers.
    // Eviction of a leftover watcher from a previous session already happens
    // once in start-watchers.sh before quickshell is launched (see
    // labwc/autostart) — pkill-ing by name here too would kill ANY
    // qs-watcher on the system, including one owned by another concurrently
    // running quickshell instance (e.g. during live-reload testing), which
    // is worse than doing nothing.
    // On exit (e.g. labwc --reconfigure), watcherRestartTimer respawns after 2 s.
    Process {
        id: watcherReader
        command: ["qs-watcher"]
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
*/
