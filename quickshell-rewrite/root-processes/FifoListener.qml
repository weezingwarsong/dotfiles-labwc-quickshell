import QtQuick
import Quickshell.Io

Item {
    id: root

    signal showTimeRequested()
    signal refreshCalendarRequested()
    signal timerSet(int seconds)
    signal timerStartRequested()
    signal timerPauseRequested()
    signal timerResetRequested()
    signal stopwatchStartRequested()
    signal stopwatchStopRequested()
    signal stopwatchResetRequested()

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

                if      (cmd === "showTime")          root.showTimeRequested()
                else if (cmd === "refreshCalendar")   root.refreshCalendarRequested()
                else if (cmd === "startTimer")        root.timerStartRequested()
                else if (cmd === "pauseTimer")        root.timerPauseRequested()
                else if (cmd === "resetTimer")        root.timerResetRequested()
                else if (cmd === "startStopwatch")    root.stopwatchStartRequested()
                else if (cmd === "stopStopwatch")     root.stopwatchStopRequested()
                else if (cmd === "resetStopwatch")    root.stopwatchResetRequested()
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
