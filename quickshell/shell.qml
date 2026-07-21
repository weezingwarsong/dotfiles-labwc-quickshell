import Quickshell
import Quickshell.Wayland
import QtQuick
import QtMultimedia
import "./root-processes"
import "./module-pills"
import "./module-panels"
import "./module-reusable-elements"
import "./module-visualizer"
import "./module-window-switcher"
import "./module-toasts"

ShellRoot {
    id: root

    FifoListener {
        id: fifo

        onShowTimeRequested:             controller.triggerPeek()
        onRefreshCalendarRequested:      calendar.refresh()
        onToggleCalendarRequested:       panelController.toggle("calendar")
        onOpenCalendarTimerRequested: {
            panelSurface.calendarInitialView = "timer"
            panelController.toggle("calendar")
        }
        onToggleWindowSwitcherRequested: windowSwitcher.toggle()
        onToggleSettingsRequested:       panelController.toggle("settings")
        onToggleWallpaperRequested:      panelController.toggle("wallpaper")
        onToggleMediaPlayerRequested:    panelController.toggle("mediaPlayer")
        onToggleNotificationsRequested:  panelController.toggle("notifications")
        onToggleControlRequested:        panelController.toggle("control")
        onTimerSet:                      function(secs) { timer.setTimer(secs) }
        onTimerStartRequested:           timer.startTimer()
        onTimerPauseRequested:           timer.pauseTimer()
        onTimerResetRequested:           timer.resetTimer()
        onStopwatchStartRequested:       timer.startStopwatch()
        onStopwatchStopRequested:        timer.stopStopwatch()
        onStopwatchResetRequested:       timer.resetStopwatch()
        onToggleVisualizerRequested:     visualizerVisible = !visualizerVisible

        onScreenshotScreenRequested:   screenshot.takeScreen()
        onScreenshotAllRequested:      screenshot.takeAll()
        onScreenshotRegionRequested:   screenshot.takeRegion()
        onScreenshotUIRequested: {
            panelSurface.notificationInitialTab = 1
            panelController.toggle("notifications")
        }
        onScreenshotNotifyRequested:   (path)   => screenshot.notifyExternalSave(path)
        onDismissToastRequested:       (id)     => toastWindow.dismiss(id)

        onScreenrecToggleRequested:              screenrec.toggle()
        onScreenrecSaveReplayRequested:          screenrec.saveReplay()
        onScreenrecSaveReplaySecondsRequested:   (n)      => screenrec.saveReplaySeconds(n)
        onScreenrecEmergencyStopRequested:       screenrec.emergencyStop()
        onScreenrecStartRegionWithRequested:     (coords) => screenrec.startRegionWith(coords)
    }

    property bool visualizerVisible: true

    CavaProcess { id: cava; active: visualizerVisible }

    SettingsProcess   { id: settings }
    ClockProcess      { id: clock }
    CalendarProcess   { id: calendar; settingsProcess: settings }
    TasksProcess      { id: tasks;    settingsProcess: settings }
    TimerProcess      { id: timer }
    LocalTimerProcess { id: localTimer }
    WeatherProcess    { id: weather;  settingsProcess: settings }
    WorkspaceProcess  { id: workspace }
    ToplevelProcess   { id: toplevels }
    MprisProcess       { id: mpris }
    WallpaperProcess   { id: wallpaper }
    NotificationServer { id: notifServer }
    AudioProcess       { id: audio }
    NetworkProcess     { id: network }
    ScreenshotProcess  { id: screenshot }
    ScreenrecProcess   { id: screenrec  }

    ToastWindow {
        id: toastWindow
        screenshotProcess:  screenshot
        screenrecProcess:   screenrec
        notificationServer: notifServer
    }

    ScreenshotOverlayWindow {
        active:    toastWindow.screenshotPreviewActive
        imagePath: toastWindow.screenshotPreviewPath
        filename:  toastWindow.screenshotPreviewFilename
    }

    BankPreviewOverlay {
        imagePath: panelSurface.hoveredScreenshotPath
    }

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
        mask: Region {}

        // Freeze the current wallpaper into _transOverlay, then let new content
        // load underneath. Ready signals (Image.Ready / PlayingState / immediate
        // for color) start the fade-out, revealing the new wallpaper beneath.
        function _beginTransition() {
            _wallFade.stop()
            if (!_transOverlay.live) _transOverlay.live = true
            _transOverlay.live    = false
            _transOverlay.opacity = 1
        }

        Item {
            id: _wallContent
            anchors.fill: parent

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
                onStatusChanged: {
                    if (status === Image.Ready && _transOverlay.opacity > 0)
                        _wallFade.start()
                }
            }

            MediaPlayer {
                id:          _vidPlayer
                source:      wallpaper.sourceType === "video" ? ("file://" + wallpaper.currentPath) : ""
                loops:       MediaPlayer.Infinite
                videoOutput: _videoOutput
                audioOutput: AudioOutput { volume: 0 }
                onSourceChanged: if (source !== "") play()
                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.PlayingState && _transOverlay.opacity > 0)
                        _wallFade.start()
                }
            }

            VideoOutput {
                id:           _videoOutput
                anchors.fill: parent
                visible:      wallpaper.sourceType === "video"
                fillMode:     VideoOutput.PreserveAspectCrop
            }
        }

        // Frozen snapshot of the previous wallpaper state, sits on top (z:10)
        // and fades out once the new content is ready underneath.
        ShaderEffectSource {
            id: _transOverlay
            sourceItem: _wallContent
            anchors.fill: parent
            live:    true
            z:       10
            opacity: 0

            NumberAnimation on opacity {
                id: _wallFade
                to: 0; duration: 500; easing.type: Easing.OutCubic
                onFinished: _transOverlay.live = true
            }
        }

        Connections {
            target: wallpaper
            function onSourceTypeChanged()  { wallpaperWindow._beginTransition() }
            function onCurrentPathChanged() { wallpaperWindow._beginTransition() }
            function onCurrentColorChanged() {
                wallpaperWindow._beginTransition()
                _wallFade.start()
            }
        }
    }

    VisualizerSurface {
        clockProcess: clock
        bars:         cava.bars
        active:       visualizerVisible
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

    WindowSwitcher {
        id: windowSwitcher
        toplevelProcess: toplevels
    }

    WindowPill {
        id: windowPill
        toplevelProcess: toplevels
        shouldShow: windowSwitcher.isOpen
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

    // Mutual exclusion: window switcher and panels cannot be open simultaneously.
    Connections {
        target: windowSwitcher
        function onIsOpenChanged() {
            if (windowSwitcher.isOpen && panelController.activePanel !== "")
                panelController.toggle(panelController.activePanel)
        }
    }
    Connections {
        target: panelController
        function onActivePanelChanged() {
            if (panelController.activePanel !== "" && windowSwitcher.isOpen)
                windowSwitcher.isOpen = false
        }
    }

    PanelSurface {
        id: panelSurface
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
        audioProcess:       audio
        networkProcess:     network
        screenshotProcess:  screenshot
        screenrecProcess:   screenrec
        onDismissRequested:  panelController.toggle(panelController.activePanel)
        onNavigateRequested: (dir) => panelController.navigate(dir)
    }
}
