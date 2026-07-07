import QtQuick
import Quickshell.Io

Item {
    id: root

    property var settingsProcess: null

    property var tasks: []        // all tasks, raw from gtask-fetch
    property var todayTasks: []   // tasks due today
    property var weekTasks: []    // tasks due within the next 7 days
    property var overdueTasks: [] // incomplete tasks past their due date
    property var tasksByDate: {}  // "YYYY-MM-DD" → [tasks] for date-based display
    property string lastUpdated: ""
    property string lastError:   ""   // "" | "auth" | "network"

    function clearData() {
        tasks        = []
        todayTasks   = []
        weekTasks    = []
        overdueTasks = []
        tasksByDate  = {}
        lastUpdated  = ""
        lastError    = ""
        console.log("[TasksProcess] data cleared")
    }

    Connections {
        target: settingsProcess
        function onGoogleDisconnected() { root.clearData() }
    }

    property string _lastOutput: ""

    function refresh() {
        if (settingsProcess && !settingsProcess.googleConnected) {
            console.log("[TasksProcess] skipping fetch — Google not connected")
            return
        }
        if (!tasksFetch.running) {
            console.log("[TasksProcess] fetching...")
            tasksFetch.running = true
        }
    }

    function _processTasks(rawTasks) {
        var now      = new Date()
        var todayStr = Qt.formatDate(now, "yyyy-MM-dd")
        var weekEndStr = Qt.formatDate(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 7), "yyyy-MM-dd")

        var today   = []
        var week    = []
        var overdue = []
        var byDate  = {}

        for (var i = 0; i < rawTasks.length; i++) {
            var t = rawTasks[i]
            var due = t.due  // "YYYY-MM-DD" or null
            var incomplete = t.status === "needsAction"

            if (due) {
                if (due === todayStr) today.push(t)
                if (due >= todayStr && due <= weekEndStr) week.push(t)
                if (due < todayStr && incomplete) overdue.push(t)

                if (!byDate[due]) byDate[due] = []
                byDate[due].push(t)
            }
        }

        root.tasks        = rawTasks
        root.todayTasks   = today
        root.weekTasks    = week
        root.overdueTasks = overdue
        root.tasksByDate  = byDate
        root.lastUpdated  = Qt.formatDateTime(now, "yyyy-MM-dd HH:mm:ss")

        console.log("[TasksProcess] fetched", rawTasks.length, "tasks.",
            "Today:", today.length, "| Overdue:", overdue.length)
    }

    Process {
        id: tasksFetch
        command: ["gtask-fetch"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._lastOutput = text
                if (text.trim() === "") return
                try {
                    var d = JSON.parse(text)
                    root._processTasks(d.tasks || [])
                    root.lastError = ""
                } catch(e) {
                    console.log("[TasksProcess] parse failed, keeping last known tasks:", e)
                }
            }
        }
        onExited: function(code, signal) {
            if (code !== 0) {
                root.lastError = root._lastOutput.trim() === "" ? "auth" : "network"
                console.log("[TasksProcess] gtask-fetch failed | lastError:", root.lastError)
            }
        }
    }

    // 10s startup delay — lets the network settle before the first fetch
    Timer {
        interval: 10000
        running: true
        repeat: false
        onTriggered: {
            root.refresh()
            repeatTimer.start()
        }
    }

    // Regular 5-minute repeat after the first fetch
    Timer {
        id: repeatTimer
        interval: 300000
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: console.log("[TasksProcess] started")
}
