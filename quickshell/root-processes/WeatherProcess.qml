import QtQuick
import Quickshell.Io

Item {
    id: root

    property var current: null  // {temp, high, low, condition, icon} — today's live weather
    property var forecast: []   // [{date, high, low, condition, icon}] × 7 days
    property string lastUpdated: ""

    function refresh() {
        if (!weatherFetch.running) {
            console.log("[WeatherProcess] fetching...")
            weatherFetch.running = true
        }
    }

    function _processWeather(data) {
        root.current = {
            temp:      data.temp,
            high:      data.high,
            low:       data.low,
            condition: data.condition,
            icon:      data.icon,
        }
        root.forecast    = data.forecast || []
        root.lastUpdated = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")

        console.log("[WeatherProcess] fetched.", data.temp + "°C,", data.condition,
            "| Forecast days:", root.forecast.length)
    }

    Process {
        id: weatherFetch
        command: ["weather-fetch"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    if (d.temp !== null)
                        root._processWeather(d)
                    else
                        console.log("[WeatherProcess] fetch returned nulls, keeping last known data")
                } catch(e) {
                    console.log("[WeatherProcess] parse failed, keeping last known data:", e)
                }
            }
        }
        onExited: function(code, signal) {
            if (code !== 0) console.log("[WeatherProcess] weather-fetch exited with code", code)
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

    Component.onCompleted: console.log("[WeatherProcess] started")
}
