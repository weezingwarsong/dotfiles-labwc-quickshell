import QtQuick
import Quickshell.Io

Item {
    id: root

    signal showTimeRequested()
    signal refreshCalendarRequested()
    signal toggleCalendarRequested()
    signal openCalendarTimerRequested()
    signal toggleWindowSwitcherRequested()
    signal toggleSettingsRequested()
    signal toggleWallpaperRequested()
    signal toggleMediaPlayerRequested()
    signal toggleNotificationsRequested()
    signal toggleControlRequested()
    signal timerSet(int seconds)
    signal timerStartRequested()
    signal timerPauseRequested()
    signal timerResetRequested()
    signal stopwatchStartRequested()
    signal stopwatchStopRequested()
    signal stopwatchResetRequested()
    signal toggleVisualizerRequested()

    signal screenshotScreenRequested()
    signal screenshotAllRequested()
    signal screenshotRegionRequested()
    signal screenshotUIRequested()
    signal screenshotNotifyRequested(string path)

    signal screenrecToggleRequested()
    signal screenrecSaveReplayRequested()
    signal screenrecSaveReplaySecondsRequested(int n)
    signal screenrecEmergencyStopRequested()
    signal screenrecStartRegionWithRequested(string coords)
    signal dismissToastRequested(string id)

    Process {
        id: fifoReader
        command: ["sh", "-c",
            "FIFO=$HOME/.local/share/pillbox/pillbox.fifo; " +
            "PIDFILE=$HOME/.local/share/pillbox/fifo-listener.pid; " +
            "mkdir -p $HOME/.local/share/pillbox; " +
            "if [ -f \"$PIDFILE\" ]; then OLD=$(cat \"$PIDFILE\"); pkill -P \"$OLD\" 2>/dev/null; kill \"$OLD\" 2>/dev/null; fi; " +
            "echo $$ > \"$PIDFILE\"; " +
            "rm -f \"$FIFO\"; mkfifo \"$FIFO\"; " +
            "exec 3<>\"$FIFO\"; " +
            "while IFS= read -r line <&3; do printf '%s\\n' \"$line\"; done"
        ]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var cmd = line.trim()
                console.log("[FifoListener] received:", cmd)

                if      (cmd === "showTime")             root.showTimeRequested()
                else if (cmd === "refreshCalendar")      root.refreshCalendarRequested()
                else if (cmd === "toggleCalendar")       root.toggleCalendarRequested()
                else if (cmd === "openCalendarTimer")    root.openCalendarTimerRequested()
                else if (cmd === "toggleWindowSwitcher") root.toggleWindowSwitcherRequested()
                else if (cmd === "toggleSettings")       root.toggleSettingsRequested()
                else if (cmd === "toggleWallpaper")      root.toggleWallpaperRequested()
                else if (cmd === "toggleMediaPlayer")    root.toggleMediaPlayerRequested()
                else if (cmd === "toggleNotifications")  root.toggleNotificationsRequested()
                else if (cmd === "toggleControl")        root.toggleControlRequested()
                else if (cmd === "startTimer")        root.timerStartRequested()
                else if (cmd === "pauseTimer")        root.timerPauseRequested()
                else if (cmd === "resetTimer")        root.timerResetRequested()
                else if (cmd === "startStopwatch")    root.stopwatchStartRequested()
                else if (cmd === "stopStopwatch")     root.stopwatchStopRequested()
                else if (cmd === "resetStopwatch")    root.stopwatchResetRequested()
                else if (cmd === "toggleVisualizer")  root.toggleVisualizerRequested()

                else if (cmd === "screenshotScreen")  root.screenshotScreenRequested()
                else if (cmd === "screenshotAll")     root.screenshotAllRequested()
                else if (cmd === "screenshotRegion")  root.screenshotRegionRequested()
                else if (cmd === "screenshotUI")      root.screenshotUIRequested()

                else if (cmd === "screenrecToggle")        root.screenrecToggleRequested()
                else if (cmd === "screenrecSaveReplay")   root.screenrecSaveReplayRequested()
                else if (cmd === "screenrecEmergencyStop") root.screenrecEmergencyStopRequested()

                else if (cmd.startsWith("screenshotNotify:"))          root.screenshotNotifyRequested(cmd.slice(17))
                else if (cmd.startsWith("screenrecStartRegionWith:"))  root.screenrecStartRegionWithRequested(cmd.slice(25))
                else if (cmd === "dismissNotification")               root.dismissToastRequested("notification")
                else if (cmd.startsWith("dismissToast:"))              root.dismissToastRequested(cmd.slice(13))
                else if (cmd.startsWith("screenrecSaveReplay:")) {
                    var n = parseInt(cmd.slice(20))
                    if (!isNaN(n) && n > 0) root.screenrecSaveReplaySecondsRequested(n)
                }

                else if (cmd.startsWith("setTimer:")) {
                    var secs = parseInt(cmd.slice(9))
                    if (!isNaN(secs) && secs > 0) root.timerSet(secs)
                }
                else console.log("[FifoListener] unknown command:", cmd)
            }
        }
        onExited: function(code, signal) {
            console.log("[FifoListener] process exited, restarting in 2s")
            restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: fifoReader.running = true
    }
}
