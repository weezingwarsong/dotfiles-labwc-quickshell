import Quickshell
import Quickshell.Wayland
import QtQuick
import "./root-processes"
import "./module-pills"
import "./module-panels"
import "./module-reusable-elements"

ShellRoot {
    id: root

    FifoListener {
        id: fifo

        onShowTimeRequested:             controller.triggerPeek()
        onRefreshCalendarRequested:      calendar.refresh()
        onToggleCalendarRequested:       panelController.toggle("calendar")
        onToggleWindowSwitcherRequested: panelController.toggle("windowSwitcher")
        onToggleSettingsRequested:       panelController.toggle("settings")
        onTimerSet:                      function(secs) { timer.setTimer(secs) }
        onTimerStartRequested:           timer.startTimer()
        onTimerPauseRequested:           timer.pauseTimer()
        onTimerResetRequested:           timer.resetTimer()
        onStopwatchStartRequested:       timer.startStopwatch()
        onStopwatchStopRequested:        timer.stopStopwatch()
        onStopwatchResetRequested:       timer.resetStopwatch()
    }

    SettingsProcess   { id: settings }
    ClockProcess      { id: clock }
    CalendarProcess   { id: calendar; settingsProcess: settings }
    TasksProcess      { id: tasks;    settingsProcess: settings }
    TimerProcess      { id: timer }
    WeatherProcess    { id: weather;  settingsProcess: settings }
    WorkspaceProcess  { id: workspace }
    ToplevelProcess   { id: toplevels }
    MprisProcess      { id: mpris }

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

    WindowPill {
        id: windowPill
        toplevelProcess: toplevels
        shouldShow: panelController.activePanel === "windowSwitcher"
    }

    MprisPill {
        id: mprisPill
        mprisProcess: mpris
    }

    HoverZone { id: hoverZone }

    PillController {
        id: controller
        hovered:       hoverZone.hovered
        timePill:      timePill
        workspacePill: workspacePill
        windowPill:    windowPill
        mprisPill:     mprisPill
    }

    PillWindow {
        activePill: controller.activePill
        shouldShow: controller.shouldShow
    }

    PanelController {
        id: panelController
    }

    // Fullscreen transparent overlay below PanelSurface (created first = lower z-order).
    // Catches clicks outside the panel and dismisses it.
    // Not shown for window switcher — it has its own dismiss path.
    PanelWindow {
        anchors.left:   true
        anchors.right:  true
        anchors.top:    true
        anchors.bottom: true
        exclusiveZone:  0
        color:          "transparent"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        visible: panelController.shouldShow && panelController.activePanel !== "windowSwitcher"

        MouseArea {
            anchors.fill: parent
            onClicked: panelController.toggle(panelController.activePanel)
        }
    }

    PanelSurface {
        activePanel:     panelController.activePanel
        shouldShow:      panelController.shouldShow
        settingsProcess: settings
        clockProcess:    clock
        calendarProcess: calendar
        tasksProcess:    tasks
        weatherProcess:  weather
        timerProcess:    timer
        toplevelProcess: toplevels
        onDismissRequested:  panelController.toggle(panelController.activePanel)
        onNavigateRequested: (dir) => panelController.navigate(dir)
    }
}
