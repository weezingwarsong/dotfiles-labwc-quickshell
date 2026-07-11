import Quickshell
import Quickshell.Wayland
import QtQuick
import QtMultimedia
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

    // Wallpaper window — Background layer, always present, covers all workspaces.
    // No external daemon: Qt renders color/image/GIF/video directly.
    PanelWindow {
        id: wallpaperWindow
        screen:        Quickshell.screens[0]
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Background
        anchors.left:   true
        anchors.right:  true
        anchors.top:    true
        anchors.bottom: true
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            visible: wallpaper.sourceType === "color"
            color:   wallpaper.currentColor
        }

        AnimatedImage {
            anchors.fill: parent
            visible:      wallpaper.sourceType === "image"
            source:       wallpaper.sourceType === "image" ? "file://" + wallpaper.currentPath : ""
            fillMode:     Image.PreserveAspectCrop
            asynchronous: true
            cache:        false
        }

        MediaPlayer {
            id:          _vidPlayer
            source:      wallpaper.sourceType === "video" ? ("file://" + wallpaper.currentPath) : ""
            loops:       MediaPlayer.Infinite
            videoOutput: _videoOutput
            audioOutput: AudioOutput { volume: 0 }
            onSourceChanged: if (source !== "") play()
        }

        VideoOutput {
            id:           _videoOutput
            anchors.fill: parent
            visible:      wallpaper.sourceType === "video"
            fillMode:     VideoOutput.PreserveAspectCrop
        }
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
