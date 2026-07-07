import QtQuick
import Quickshell.Io

Item {
    id: root

    property var settingsProcess: null

    property var events: []       // all events, raw from gcal-fetch
    property var nextEvent: null  // first upcoming event (start >= now)
    property var todayEvents: []  // events whose start date is today
    property var weekEvents: []   // events whose start date is within the next 7 days
    property var eventsByDate: {} // "YYYY-MM-DD" → [events] for month view dot indicators
    property string lastUpdated: ""
    property string lastError:   ""   // "" | "auth" | "network"

    // Cleared when user disconnects Google account — wipes all in-memory data.
    function clearData() {
        events      = []
        nextEvent   = null
        todayEvents = []
        weekEvents  = []
        eventsByDate = {}
        lastUpdated = ""
        lastError   = ""
        console.log("[CalendarProcess] data cleared")
    }

    Connections {
        target: settingsProcess
        function onGoogleDisconnected() { root.clearData() }
    }

    property string _lastOutput: ""

    function refresh() {
        if (settingsProcess && !settingsProcess.googleConnected) {
            console.log("[CalendarProcess] skipping fetch — Google not connected")
            return
        }
        if (!calendarFetch.running) {
            console.log("[CalendarProcess] fetching...")
            calendarFetch.running = true
        }
    }

    function _processEvents(rawEvents) {
        var now = new Date()
        var todayStr   = Qt.formatDate(now, "yyyy-MM-dd")
        var weekEndStr = Qt.formatDate(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 7), "yyyy-MM-dd")

        var next     = null
        var today    = []
        var week     = []
        var byDate   = {}

        for (var i = 0; i < rawEvents.length; i++) {
            var e = rawEvents[i]
            var dateStr = e.start.substring(0, 10)

            // nextEvent: first event whose start is >= now
            if (!next) {
                var upcoming = e.allDay ? dateStr >= todayStr : new Date(e.start) >= now
                if (upcoming) next = e
            }

            // todayEvents
            if (dateStr === todayStr) today.push(e)

            // weekEvents: today through today+7
            if (dateStr >= todayStr && dateStr <= weekEndStr) week.push(e)

            // eventsByDate
            if (!byDate[dateStr]) byDate[dateStr] = []
            byDate[dateStr].push(e)
        }

        root.events       = rawEvents
        root.nextEvent    = next
        root.todayEvents  = today
        root.weekEvents   = week
        root.eventsByDate = byDate
        root.lastUpdated  = Qt.formatDateTime(now, "yyyy-MM-dd HH:mm:ss")

        console.log("[CalendarProcess] fetched", rawEvents.length, "events.",
            "Today:", today.length, "| Next:", next ? next.summary + " at " + next.start : "none")
    }

    Process {
        id: calendarFetch
        command: ["gcal-fetch"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._lastOutput = text
                if (text.trim() === "") return  // auth failure — no JSON; lastError set in onExited
                try {
                    var d = JSON.parse(text)
                    root._processEvents(d.events || [])
                    root.lastError = ""
                } catch(e) {
                    console.log("[CalendarProcess] parse failed, keeping last known events:", e)
                }
            }
        }
        onExited: function(code, signal) {
            if (code !== 0) {
                root.lastError = root._lastOutput.trim() === "" ? "auth" : "network"
                console.log("[CalendarProcess] gcal-fetch failed | lastError:", root.lastError)
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

    Component.onCompleted: console.log("[CalendarProcess] started")
}
