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
        onToggleWallpaperRequested:      panelController.toggle("wallpaper")
        onToggleMediaPlayerRequested:    panelController.toggle("mediaPlayer")
        onToggleNotificationsRequested:  panelController.toggle("notifications")
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
    MprisProcess       { id: mpris }
    WallpaperProcess   { id: wallpaper }
    NotificationServer { id: notifServer }

    // Solid color background — only visible when wallpaper source is "color".
    // yin handles image/video; this Rectangle handles the trivial solid case.
    PanelWindow {
        id: colorBg
        screen:        Quickshell.screens[0]
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Background
        anchors.left:   true
        anchors.right:  true
        anchors.top:    true
        anchors.bottom: true
        color: wallpaper.currentColor
        visible: wallpaper.sourceType === "color"
    }

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

    NotificationPill {
        id: notificationPill
        notificationServer: notifServer
    }

    HoverZone { id: hoverZone }

    PillController {
        id: controller
        hovered:       hoverZone.hovered
        timePill:      timePill
        workspacePill: workspacePill
        windowPill:    windowPill
        mprisPill:          mprisPill
        notificationPill:   notificationPill
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
        settingsProcess: settings
        clockProcess:    clock
        calendarProcess: calendar
        tasksProcess:    tasks
        weatherProcess:  weather
        timerProcess:    timer
        toplevelProcess:  toplevels
        wallpaperProcess: wallpaper
        mprisProcess:       mpris
        notificationServer: notifServer
        onDismissRequested:  panelController.toggle(panelController.activePanel)
        onNavigateRequested: (dir) => panelController.navigate(dir)
    }
}
