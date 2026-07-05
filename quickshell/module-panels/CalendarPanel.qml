import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Item {
    id: root

    // ── Injected processes ────────────────────────────────────────────────────
    property var clockProcess:    null
    property var calendarProcess: null
    property var tasksProcess:    null
    property var weatherProcess:  null
    property var timerProcess:    null

    // ── View state ────────────────────────────────────────────────────────────
    property string _view: "glance"  // "glance" | "expanded"

    // ── Month navigation ──────────────────────────────────────────────────────
    property int _navYear:  0
    property int _navMonth: 0

    Component.onCompleted: _resetNav()
    onClockProcessChanged: if (clockProcess && _navYear === 0) _resetNav()

    function _resetNav() {
        var now = clockProcess ? clockProcess.now : new Date()
        _navYear  = now.getFullYear()
        _navMonth = now.getMonth()
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _pad(n) { return n < 10 ? "0" + n : "" + n }

    function _eventTime(start, allDay) {
        if (allDay || !start || start.length === 10) return "all day"
        return Qt.formatTime(new Date(start), "HH:mm")
    }

    function _dayLabel(dateStr) {
        var now      = clockProcess ? clockProcess.now : new Date()
        var today    = Qt.formatDate(now, "yyyy-MM-dd")
        var tomorrow = Qt.formatDate(new Date(now.getTime() + 86400000), "yyyy-MM-dd")
        if (dateStr === today)    return "Today"
        if (dateStr === tomorrow) return "Tomorrow"
        return Qt.formatDate(new Date(dateStr + "T00:00:00"), "ddd d MMM")
    }

    function _firstDayOfMonth(year, month) {
        return (new Date(year, month, 1).getDay() + 6) % 7  // Mon=0 … Sun=6
    }

    function _daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate()
    }

    // Month grid: 42 cells (6 rows × 7 cols), Monday-first
    readonly property var _gridCells: {
        var firstDay    = _firstDayOfMonth(_navYear, _navMonth)
        var totalDays   = _daysInMonth(_navYear, _navMonth)
        var now         = clockProcess ? clockProcess.now : new Date()
        var thisMonth   = (_navYear === now.getFullYear() && _navMonth === now.getMonth())
        var todayDay    = thisMonth ? now.getDate() : -1
        var byDate      = calendarProcess ? calendarProcess.eventsByDate : {}
        var tasksByDate = tasksProcess    ? tasksProcess.tasksByDate     : {}
        var cells       = []
        for (var i = 0; i < 42; i++) {
            var d = i - firstDay + 1
            if (d < 1 || d > totalDays) {
                cells.push({ day: 0, isToday: false, hasContent: false,
                             dateStr: "", events: [], tasks: [] })
            } else {
                var ds   = _navYear + "-" + _pad(_navMonth + 1) + "-" + _pad(d)
                var evts = byDate[ds]      || []
                var tsks = tasksByDate[ds] || []
                cells.push({ day: d, isToday: d === todayDay,
                             hasContent: evts.length > 0 || tsks.length > 0,
                             dateStr: ds, events: evts, tasks: tsks })
            }
        }
        return cells
    }

    // Flat event list with date-header sentinels for the week view
    readonly property var _weekItems: {
        var evts  = calendarProcess ? calendarProcess.weekEvents : []
        var items = []
        var last  = ""
        for (var i = 0; i < evts.length; i++) {
            var ds = evts[i].start.substring(0, 10)
            if (ds !== last) { items.push({ type: "header", label: _dayLabel(ds) }); last = ds }
            items.push({ type: "event", summary: evts[i].summary || "",
                         start: evts[i].start, allDay: evts[i].allDay || false })
        }
        return items
    }

    // Flat task list with date-header sentinels for the week view
    readonly property var _weekTaskItems: {
        var tsks  = tasksProcess ? tasksProcess.weekTasks : []
        var items = []
        var last  = ""
        for (var i = 0; i < tsks.length; i++) {
            var due = tsks[i].due || ""
            if (due !== last) { items.push({ type: "header", label: due ? _dayLabel(due) : "No date" }); last = due }
            items.push({ type: "task", title: tsks[i].title || "" })
        }
        return items
    }

    // ── FIFO writer ───────────────────────────────────────────────────────────
    Process {
        id: fifoWriter
    }
    function _send(cmd) {
        if (!fifoWriter.running) {
            fifoWriter.command = ["sh", "-c",
                "echo '" + cmd + "' > $HOME/.local/share/pillbox/pillbox.fifo"]
            fifoWriter.running = true
        }
    }

    // ── Root visual ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Style.radiusPanel
        color: Style.panelBg
        border.color: Style.panelBorder
        border.width: 1
        clip: true

        // ── Glance view ───────────────────────────────────────────────────────
        Flickable {
            id: glanceFlick
            anchors.fill: parent
            contentHeight: glanceCol.implicitHeight
            clip: true
            visible: root._view === "glance"
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: glanceCol
                width: parent.width
                spacing: 0

                Item { width: 1; height: 12 }

                // Date + weather
                Item {
                    x: 12; width: glanceCol.width - 24; height: 20
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: clockProcess ? Qt.formatDate(clockProcess.now, "ddd, d MMM yyyy") : "--"
                        color: Style.textPrimary; font.pixelSize: Style.textMd; font.weight: Font.Medium
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: weatherProcess && weatherProcess.current
                                ? String.fromCharCode(parseInt(weatherProcess.current.icon, 16)) : ""
                            color: Style.textSoft; font.family: Style.fontNerd; font.pixelSize: Style.textLg
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: weatherProcess && weatherProcess.current
                                ? weatherProcess.current.temp + "°" : "--°"
                            color: Style.textNormal; font.pixelSize: Style.textMd
                        }
                    }
                }

                // Condition + high/low
                Text {
                    x: 12; width: glanceCol.width - 24
                    text: weatherProcess && weatherProcess.current
                        ? weatherProcess.current.condition + "  " +
                          weatherProcess.current.high + "° / " + weatherProcess.current.low + "°"
                        : ""
                    color: Style.textSubtle; font.pixelSize: Style.textXxs
                    topPadding: 2; bottomPadding: 10
                }

                // Month nav
                Item {
                    x: 12; width: glanceCol.width - 24; height: 18
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: "‹"; color: Style.textSubtle; font.pixelSize: Style.textSm; font.weight: Font.Bold
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            onClicked: {
                                if (root._navMonth === 0) { root._navYear--; root._navMonth = 11 }
                                else root._navMonth--
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: ["January","February","March","April","May","June",
                               "July","August","September","October","November","December"][root._navMonth] +
                              " " + root._navYear
                        color: Style.textNormal; font.pixelSize: Style.textXs; font.weight: Font.Medium
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: "›"; color: Style.textSubtle; font.pixelSize: Style.textSm; font.weight: Font.Bold
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            onClicked: {
                                if (root._navMonth === 11) { root._navYear++; root._navMonth = 0 }
                                else root._navMonth++
                            }
                        }
                    }
                }

                // Day-of-week headers
                Row {
                    x: 12; width: glanceCol.width - 24; height: 16; topPadding: 6
                    Repeater {
                        model: ["M","T","W","T","F","S","S"]
                        Text {
                            width: (glanceCol.width - 24) / 7; height: 10
                            text: modelData
                            color: index >= 5 ? Style.weekend : Style.textDim
                            font.pixelSize: Style.textXxs; horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Month grid
                Grid {
                    x: 12; width: glanceCol.width - 24; columns: 7
                    topPadding: 2; bottomPadding: 4

                    Repeater {
                        model: root._gridCells

                        Item {
                            id: cellItem
                            // Capture modelData before inner Repeaters shadow it
                            property var cell: modelData
                            width: (glanceCol.width - 24) / 7; height: 20

                            Rectangle {
                                anchors.centerIn: parent; width: 16; height: 16; radius: Style.radiusToday
                                color: cellItem.cell.isToday ? Style.accent : "transparent"
                                visible: cellItem.cell.day > 0
                            }
                            Text {
                                anchors.centerIn: parent
                                text: cellItem.cell.day > 0 ? cellItem.cell.day : ""
                                color: cellItem.cell.isToday ? Style.textPrimary : Style.textLight
                                font.pixelSize: Style.textXxs
                                font.weight: cellItem.cell.isToday ? Font.Bold : Font.Normal
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: 3; height: 3; radius: 1.5
                                color: cellItem.cell.isToday ? Style.accentFaint : Style.accent
                                visible: cellItem.cell.day > 0 && cellItem.cell.hasContent
                            }

                            HoverHandler { id: cellHover }
                            ToolTip {
                                visible: cellHover.hovered && cellItem.cell.day > 0 &&
                                         (cellItem.cell.events.length > 0 || cellItem.cell.tasks.length > 0)
                                delay: 300
                                contentItem: Column {
                                    spacing: 2
                                    Repeater {
                                        model: cellItem.cell.events.slice(0, 4)
                                        Text {
                                            text: "• " + (modelData.summary || "")
                                            color: Style.textSoft; font.pixelSize: Style.textXs
                                        }
                                    }
                                    Repeater {
                                        model: cellItem.cell.tasks.slice(0, 4)
                                        Text {
                                            text: "○ " + (modelData.title || "")
                                            color: Style.textMuted; font.pixelSize: Style.textXs
                                        }
                                    }
                                }
                                background: Rectangle {
                                    color: Style.surfaceMid; border.color: Style.tooltipBorder; radius: Style.radiusTooltip
                                }
                            }
                        }
                    }
                }

                Rectangle { x: 12; width: glanceCol.width - 24; height: 1; color: Style.divider }
                Item { width: 1; height: 8 }

                // Events today
                Text {
                    x: 12; text: "EVENTS TODAY"
                    color: Style.textDim; font.pixelSize: Style.textLabel; font.letterSpacing: 0.8; height: 12
                }
                Item { width: 1; height: 4 }
                Repeater {
                    model: calendarProcess ? calendarProcess.todayEvents.slice(0, 3) : []
                    Row {
                        x: 12; width: glanceCol.width - 24; height: 16; spacing: 6
                        Text {
                            width: 38; height: parent.height; verticalAlignment: Text.AlignVCenter
                            text: root._eventTime(modelData.start, modelData.allDay)
                            color: Style.textSubtle; font.pixelSize: Style.textXs
                        }
                        Text {
                            width: parent.width - 44; height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.summary || ""
                            color: Style.textNormal; font.pixelSize: Style.textXs; elide: Text.ElideRight
                        }
                    }
                }
                Text {
                    x: 12; height: 16
                    visible: !calendarProcess || calendarProcess.todayEvents.length === 0
                    text: "No events today"; color: Style.textFaint; font.pixelSize: Style.textXs
                }

                Item { width: 1; height: 8 }

                // Tasks today
                Text {
                    x: 12; text: "TASKS TODAY"
                    color: Style.textDim; font.pixelSize: Style.textLabel; font.letterSpacing: 0.8; height: 12
                }
                Item { width: 1; height: 4 }
                Repeater {
                    model: tasksProcess ? tasksProcess.todayTasks.slice(0, 3) : []
                    Row {
                        x: 12; width: glanceCol.width - 24; height: 16; spacing: 6
                        Text {
                            height: parent.height; verticalAlignment: Text.AlignVCenter
                            text: "○"; color: Style.textDim; font.pixelSize: Style.textSm
                        }
                        Text {
                            width: parent.width - 16; height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.title || ""
                            color: Style.textNormal; font.pixelSize: Style.textXs; elide: Text.ElideRight
                        }
                    }
                }
                Text {
                    x: 12; height: 16
                    visible: !tasksProcess || tasksProcess.todayTasks.length === 0
                    text: "No tasks today"; color: Style.textFaint; font.pixelSize: Style.textXs
                }

                Item { width: 1; height: 8 }
                Rectangle { x: 12; width: glanceCol.width - 24; height: 1; color: Style.divider }
                Item { width: 1; height: 8 }

                // Footer buttons
                Row {
                    x: 12; width: glanceCol.width - 24; height: 22; spacing: 6
                    Rectangle {
                        width: (parent.width - 6) / 2; height: 20; radius: Style.radiusBtn
                        color: moreHover.containsMouse ? Style.surfaceMid : Style.surfaceLow
                        border.color: Style.borderSoft; border.width: 1
                        Text { anchors.centerIn: parent; text: "More ↓"; color: Style.textBtn; font.pixelSize: Style.textXs }
                        MouseArea { id: moreHover; anchors.fill: parent; hoverEnabled: true
                            onClicked: root._view = "expanded" }
                    }
                    Rectangle {
                        width: (parent.width - 6) / 2; height: 20; radius: Style.radiusBtn
                        color: editHover.containsMouse ? Style.surfaceMid : Style.surfaceLow
                        border.color: Style.borderSoft; border.width: 1
                        Text { anchors.centerIn: parent; text: "Edit ↗"; color: Style.textBtn; font.pixelSize: Style.textXs }
                        MouseArea { id: editHover; anchors.fill: parent; hoverEnabled: true
                            onClicked: Qt.openUrlExternally("https://calendar.google.com") }
                    }
                }

                Item { width: 1; height: 12 }
            }
        }

        // ── Expanded view ─────────────────────────────────────────────────────
        Flickable {
            id: expandedFlick
            anchors.fill: parent
            contentHeight: expandedCol.implicitHeight
            clip: true
            visible: root._view === "expanded"
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: expandedCol
                width: parent.width
                spacing: 0

                Item { width: 1; height: 12 }

                Text {
                    x: 12; text: "↑ Back"
                    color: Style.accent; font.pixelSize: Style.textSm; height: 20
                    verticalAlignment: Text.AlignVCenter
                    MouseArea { anchors.fill: parent; onClicked: root._view = "glance" }
                }

                Item { width: 1; height: 10 }

                // ── This week — events ────────────────────────────────────────
                Text {
                    x: 12; text: "THIS WEEK"
                    color: Style.textDim; font.pixelSize: Style.textLabel; font.letterSpacing: 0.8; height: 12
                }
                Item { width: 1; height: 4 }

                Repeater {
                    model: root._weekItems
                    Item {
                        x: 12; width: expandedCol.width - 24
                        height: modelData.type === "header" ? 18 : 16
                        property bool isHeader: modelData.type === "header"
                        property string itemLabel:   modelData.type === "header" ? modelData.label : ""
                        property string itemSummary: modelData.type === "event"  ? modelData.summary : ""
                        property string itemStart:   modelData.type === "event"  ? modelData.start   : ""
                        property bool   itemAllDay:  modelData.type === "event"  && modelData.allDay

                        Text {
                            visible: parent.isHeader
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                            text: parent.itemLabel
                            color: Style.textDim; font.pixelSize: Style.textXxs; font.weight: Font.Medium
                        }
                        Row {
                            visible: !parent.isHeader
                            anchors.fill: parent; spacing: 6
                            Text {
                                width: 38; height: parent.height; verticalAlignment: Text.AlignVCenter
                                text: root._eventTime(parent.itemStart, parent.itemAllDay)
                                color: Style.textSubtle; font.pixelSize: Style.textXs
                            }
                            Text {
                                width: parent.width - 44; height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: parent.itemSummary
                                color: Style.textNormal; font.pixelSize: Style.textXs; elide: Text.ElideRight
                            }
                        }
                    }
                }
                Text {
                    x: 12; height: 16
                    visible: !calendarProcess || calendarProcess.weekEvents.length === 0
                    text: "No events this week"; color: Style.textFaint; font.pixelSize: Style.textXs
                }

                Item { width: 1; height: 10 }

                // ── This week — tasks ─────────────────────────────────────────
                Text {
                    x: 12; text: "TASKS THIS WEEK"
                    color: Style.textDim; font.pixelSize: Style.textLabel; font.letterSpacing: 0.8; height: 12
                }
                Item { width: 1; height: 4 }

                Repeater {
                    model: root._weekTaskItems
                    Item {
                        x: 12; width: expandedCol.width - 24
                        height: modelData.type === "header" ? 18 : 16
                        property bool   isHeader:  modelData.type === "header"
                        property string itemLabel: modelData.type === "header" ? modelData.label : ""
                        property string itemTitle: modelData.type === "task"   ? modelData.title : ""

                        Text {
                            visible: parent.isHeader
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                            text: parent.itemLabel
                            color: Style.textDim; font.pixelSize: Style.textXxs; font.weight: Font.Medium
                        }
                        Row {
                            visible: !parent.isHeader
                            anchors.fill: parent; spacing: 6
                            Text {
                                height: parent.height; verticalAlignment: Text.AlignVCenter
                                text: "○"; color: Style.textDim; font.pixelSize: Style.textSm
                            }
                            Text {
                                width: parent.width - 16; height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: parent.itemTitle
                                color: Style.textNormal; font.pixelSize: Style.textXs; elide: Text.ElideRight
                            }
                        }
                    }
                }
                Text {
                    x: 12; height: 16
                    visible: !tasksProcess || tasksProcess.weekTasks.length === 0
                    text: "No tasks this week"; color: Style.textFaint; font.pixelSize: Style.textXs
                }

                Item { width: 1; height: 10 }

                // ── 7-day forecast ────────────────────────────────────────────
                Text {
                    x: 12; text: "7-DAY FORECAST"
                    color: Style.textDim; font.pixelSize: Style.textLabel; font.letterSpacing: 0.8; height: 12
                }
                Item { width: 1; height: 4 }

                Repeater {
                    model: weatherProcess ? weatherProcess.forecast : []
                    Row {
                        x: 12; width: expandedCol.width - 24; height: 18; spacing: 6
                        Text {
                            width: 56; height: parent.height; verticalAlignment: Text.AlignVCenter
                            text: root._dayLabel(modelData.date)
                            color: Style.textMuted; font.pixelSize: Style.textXs; elide: Text.ElideRight
                        }
                        Text {
                            height: parent.height; verticalAlignment: Text.AlignVCenter
                            text: String.fromCharCode(parseInt(modelData.icon, 16))
                            color: Style.textMuted; font.family: Style.fontNerd; font.pixelSize: Style.textMd
                        }
                        Text {
                            // Fill remaining space minus the temp column
                            width: expandedCol.width - 24 - 56 - 18 - 6*3 - 62
                            height: parent.height; verticalAlignment: Text.AlignVCenter
                            text: modelData.condition
                            color: Style.textMuted; font.pixelSize: Style.textXs; elide: Text.ElideRight
                        }
                        Text {
                            width: 62; height: parent.height; verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignRight
                            text: modelData.high + "° / " + modelData.low + "°"
                            color: Style.textNormal; font.pixelSize: Style.textXs
                        }
                    }
                }

                Item { width: 1; height: 10 }
                Rectangle { x: 12; width: expandedCol.width - 24; height: 1; color: Style.divider }
                Item { width: 1; height: 10 }

                // ── Timer / stopwatch ─────────────────────────────────────────
                Text {
                    x: 12; text: "TIMER"
                    color: Style.textDim; font.pixelSize: Style.textLabel; font.letterSpacing: 0.8; height: 12
                }
                Item { width: 1; height: 8 }

                Text {
                    x: 12; width: expandedCol.width - 24; height: 28
                    text: timerProcess ? timerProcess.displayText : "--:--"
                    color: Style.textPrimary; font.pixelSize: Style.textXl; font.family: Style.fontMono
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                Text {
                    x: 12; width: expandedCol.width - 24; height: 14
                    text: timerProcess
                        ? (timerProcess.mode === "timer" ? "Countdown" : "Stopwatch") : ""
                    color: Style.textDim; font.pixelSize: Style.textXxs
                    horizontalAlignment: Text.AlignHCenter
                }
                Item { width: 1; height: 6 }

                // Countdown presets (shown only in timer mode)
                Row {
                    x: 12; width: expandedCol.width - 24; height: 22; spacing: 4
                    visible: !timerProcess || timerProcess.mode === "timer"
                    Repeater {
                        model: [
                            { label: "5m",  cmd: "setTimer:300"  },
                            { label: "10m", cmd: "setTimer:600"  },
                            { label: "25m", cmd: "setTimer:1500" },
                        ]
                        Rectangle {
                            width: (expandedCol.width - 24 - 8) / 3; height: 20; radius: Style.radiusBtnSm
                            color: presetHover.containsMouse ? Style.surfaceMid : Style.surfaceLow
                            border.color: Style.borderSoft; border.width: 1
                            Text { anchors.centerIn: parent; text: modelData.label; color: Style.textBtn; font.pixelSize: Style.textXs }
                            MouseArea { id: presetHover; anchors.fill: parent; hoverEnabled: true
                                onClicked: root._send(modelData.cmd) }
                        }
                    }
                }
                Item {
                    width: 1; height: 4
                    visible: !timerProcess || timerProcess.mode === "timer"
                }

                // Start/pause + reset
                Row {
                    x: 12; width: expandedCol.width - 24; height: 22; spacing: 6
                    Rectangle {
                        width: (parent.width - 6) / 2; height: 20; radius: Style.radiusBtnSm
                        color: startHover.containsMouse ? Style.accentBgHover : Style.accentBg
                        border.color: Style.accent; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (!timerProcess || !timerProcess.running) return "Start"
                                return timerProcess.mode === "stopwatch" ? "Stop" : "Pause"
                            }
                            color: Style.accentText; font.pixelSize: Style.textXs
                        }
                        MouseArea { id: startHover; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (!timerProcess) return
                                if (timerProcess.mode === "stopwatch")
                                    root._send(timerProcess.running ? "stopStopwatch" : "startStopwatch")
                                else
                                    root._send(timerProcess.running ? "pauseTimer" : "startTimer")
                            }
                        }
                    }
                    Rectangle {
                        width: (parent.width - 6) / 2; height: 20; radius: Style.radiusBtnSm
                        color: resetHover.containsMouse ? Style.surfaceMid : Style.surfaceLow
                        border.color: Style.borderSoft; border.width: 1
                        Text { anchors.centerIn: parent; text: "Reset"; color: Style.textBtn; font.pixelSize: Style.textXs }
                        MouseArea { id: resetHover; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (!timerProcess) return
                                root._send(timerProcess.mode === "stopwatch" ? "resetStopwatch" : "resetTimer")
                            }
                        }
                    }
                }
                Item { width: 1; height: 4 }

                // Mode switcher tabs
                Row {
                    x: 12; width: expandedCol.width - 24; height: 22; spacing: 6
                    Repeater {
                        model: [
                            { label: "Countdown", mode: "timer",     startCmd: "startTimer"     },
                            { label: "Stopwatch", mode: "stopwatch", startCmd: "startStopwatch" },
                        ]
                        Rectangle {
                            property bool active: timerProcess && timerProcess.mode === modelData.mode
                            width: (expandedCol.width - 24 - 6) / 2; height: 18; radius: Style.radiusBtnSm
                            color: active ? Style.accentBg : (modeHover.containsMouse ? Style.surfaceLow : "transparent")
                            border.color: active ? Style.accent : Style.borderFaint; border.width: 1
                            Text {
                                anchors.centerIn: parent; text: modelData.label
                                color: parent.active ? Style.accentText : Style.textDim; font.pixelSize: Style.textXxs
                            }
                            MouseArea { id: modeHover; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if (!timerProcess || timerProcess.mode !== modelData.mode)
                                        root._send(modelData.startCmd)
                                }
                            }
                        }
                    }
                }

                Item { width: 1; height: 12 }
            }
        }
    }
}
