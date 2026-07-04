import QtQuick
import Quickshell.Io

Item {
    id: root

    property var events: []
    property var nextEvent: null
    property string lastUpdated: ""

    function refresh() {
        if (!calendarFetch.running) {
            console.log("[CalendarProcess] fetching...")
            calendarFetch.running = true
        }
    }

    Process {
        id: calendarFetch
        command: ["gcal-fetch"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.events = d.events || []
                    root.nextEvent = root.events.length > 0 ? root.events[0] : null
                    root.lastUpdated = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
                    console.log("[CalendarProcess] fetched", root.events.length, "events. Next:", root.nextEvent ? root.nextEvent.title + " at " + root.nextEvent.start : "none")
                } catch(e) {
                    console.log("[CalendarProcess] parse failed, keeping last known events:", e)
                }
            }
        }
        onExited: function(code, signal) {
            if (code !== 0) console.log("[CalendarProcess] gcal-fetch exited with code", code)
        }
    }

    // Fetch every 5 minutes, and immediately on start
    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: console.log("[CalendarProcess] started")
}
