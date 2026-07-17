import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import Quickshell

Item {
    id: root
    focus: true

    // ── Injected processes ────────────────────────────────────────────────────
    property var clockProcess:    null
    property var calendarProcess: null
    property var tasksProcess:    null
    property var weatherProcess:  null
    property var timerProcess:    null

    // ── View state ────────────────────────────────────────────────────────────
    property string _view: "glance"  // "glance" | "expanded" | "timer"
    property bool _eventsCollapsed: false
    property bool _tasksCollapsed:  false
    property bool _timerCollapsed:  false
    property bool _pickerOpen:      false

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_N:
            if (root._navMonth === 11) { root._navYear++; root._navMonth = 0 }
            else root._navMonth++
            root._pickerOpen = false
            event.accepted = true; break
        case Qt.Key_B:
            if (root._navMonth === 0) { root._navYear--; root._navMonth = 11 }
            else root._navMonth--
            root._pickerOpen = false
            event.accepted = true; break
        case Qt.Key_P:
            if (root._view !== "timer" || !root.timerProcess) { event.accepted = false; break }
            if (root.timerProcess.mode === "stopwatch") {
                if (root.timerProcess.active) root.timerProcess.stopStopwatch()
                else                          root.timerProcess.startStopwatch()
            } else {
                if (root.timerProcess.active) root.timerProcess.pauseTimer()
                else                          root.timerProcess.startTimer()
            }
            event.accepted = true; break
        case Qt.Key_M:
            if (root._view === "timer") {
                if (!root.timerProcess) { event.accepted = false; break }
                root.timerProcess.setMode(root.timerProcess.mode === "stopwatch" ? "timer" : "stopwatch")
            } else {
                root._pickerOpen = !root._pickerOpen
            }
            event.accepted = true; break
        case Qt.Key_R:
            if (root._view === "timer") {
                if (!root.timerProcess) { event.accepted = false; break }
                if (root.timerProcess.mode === "stopwatch") root.timerProcess.resetStopwatch()
                else                                         root.timerProcess.resetTimer()
            } else {
                if (root.calendarProcess) root.calendarProcess.refresh()
                if (root.tasksProcess)    root.tasksProcess.refresh()
            }
            event.accepted = true; break
        case Qt.Key_0:
        case Qt.Key_Insert:
            if (root._view !== "timer" || !root.timerProcess || root.timerProcess.mode === "stopwatch") { event.accepted = false; break }
            _timerWidget._inputExpanded = true
            event.accepted = true; break
        case Qt.Key_E:
            Qt.openUrlExternally("https://calendar.google.com")
            event.accepted = true; break
        case Qt.Key_Tab:
            root._view = root._view === "glance" ? "expanded" : root._view === "expanded" ? "timer" : "glance"
            event.accepted = true; break
        default:
            event.accepted = false
        }
    }

    property string activePanel: ""
    signal navigateRequested(int direction)

    // Nav arrows and task bullets — fixed at 11px (between body and heading)
    readonly property int _navSize: 11

    implicitHeight: {
        var tab = _tabBar ? _tabBar.implicitHeight : 0
        if (_view === "glance")   return tab + glanceFlick.contentHeight
        if (_view === "expanded") return tab + expandedFlick.contentHeight
        if (_view === "timer")    return tab + timerFlick.contentHeight
        return tab
    }

    // ── Month navigation ──────────────────────────────────────────────────────
    property int _navYear:  0
    property int _navMonth: 0

    Component.onCompleted: { _resetNav(); forceActiveFocus() }
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

    readonly property var _gridCells: {
        var firstDay    = _firstDayOfMonth(_navYear, _navMonth)
        var totalDays   = _daysInMonth(_navYear, _navMonth)
        var now         = clockProcess ? clockProcess.now : new Date()
        var thisMonth   = (_navYear === now.getFullYear() && _navMonth === now.getMonth())
        var todayDay    = thisMonth ? now.getDate() : -1
        var byDate      = calendarProcess ? calendarProcess.eventsByDate : {}
        var tasksByDate = tasksProcess    ? tasksProcess.tasksByDate     : {}
        var numCells = Math.ceil((firstDay + totalDays) / 7) * 7
        var cells    = []
        for (var i = 0; i < numCells; i++) {
            var d = i - firstDay + 1
            if (d < 1 || d > totalDays) {
                cells.push({ day: 0, isToday: false, hasContent: false, dateStr: "", events: [], tasks: [] })
            } else {
                var ds   = _navYear + "-" + _pad(_navMonth + 1) + "-" + _pad(d)
                var evts = byDate[ds]      || []
                var tsks = tasksByDate[ds] || []
                cells.push({ day: d, isToday: d === todayDay, hasContent: evts.length > 0 || tsks.length > 0, dateStr: ds, events: evts, tasks: tsks })
            }
        }
        return cells
    }

    readonly property var _weekItems: {
        var evts  = calendarProcess ? calendarProcess.weekEvents : []
        var items = []
        var last  = ""
        for (var i = 0; i < evts.length; i++) {
            var ds = evts[i].start.substring(0, 10)
            if (ds !== last) { items.push({ type: "header", label: _dayLabel(ds) }); last = ds }
            items.push({ type: "event", summary: evts[i].summary || "", start: evts[i].start, allDay: evts[i].allDay || false })
        }
        return items
    }

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

    // ── Persistent tab bar ────────────────────────────────────────────────────
    PanelTabBar {
        id: _tabBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        labels:   ["Main", "Upcoming", "Timer"]
        glyphs:   [String.fromCodePoint(0xf073), String.fromCodePoint(0xf0ae), String.fromCodePoint(0xf017)]
        selected: root._view === "glance" ? 0 : root._view === "expanded" ? 1 : root._view === "timer" ? 2 : 0
        onToggled: (i) => root._view = (i === 0 ? "glance" : i === 1 ? "expanded" : "timer")
    }

    // ── Glance view ───────────────────────────────────────────────────────────
    Flickable {
        id: glanceFlick
        anchors { left: parent.left; right: parent.right; top: _tabBar.bottom; bottom: parent.bottom }
        contentWidth:  width
        contentHeight: glanceCol.implicitHeight + 24
        visible: root._view === "glance"
        flickableDirection: Flickable.VerticalFlick
        clip: true

        ColumnLayout {
            id: glanceCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors { leftMargin: 12; rightMargin: 12; topMargin: 12 }
            spacing: 8

            PanelCard {
                Layout.fillWidth: true

                // Row 1: Date + weather
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: clockProcess ? Qt.formatDate(clockProcess.now, "ddd, d MMM yyyy") : "--"
                        color: Style.textPrimary; font.pixelSize: Style.fontSizeHeading; font.weight: Font.Medium
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.fillWidth: true }
                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            text: weatherProcess && weatherProcess.current ? String.fromCharCode(parseInt(weatherProcess.current.icon, 16)) : ""
                            color: Style.textMuted; font.family: Style.fontNerd; font.pixelSize: Style.fontSizeHeading
                        }
                        Text {
                            text: weatherProcess && weatherProcess.current ? weatherProcess.current.temp + "°" : "--°"
                            color: Style.textNormal; font.pixelSize: Style.fontSizeHeading
                        }
                    }
                }

                // Condition + high/low
                Text {
                    Layout.fillWidth: true
                    text: weatherProcess && weatherProcess.current ? weatherProcess.current.condition + "  " + weatherProcess.current.high + "° / " + weatherProcess.current.low + "°" : ""
                    color: Style.textMuted; font.pixelSize: Style.fontSizeSubtle
                }

                // Row 2: Month section (left) | Action buttons (right)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Column 1: month nav + combined grid
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            IconButton {
                                label:   String.fromCodePoint(0xf104)
                                tooltip: root._pickerOpen ? "Previous year" : "Previous month"
                                onClicked: {
                                    if (root._pickerOpen) { root._navYear-- }
                                    else if (root._navMonth === 0) { root._navYear--; root._navMonth = 11 }
                                    else root._navMonth--
                                }
                            }
                            Item { Layout.fillWidth: true }
                            PanelButton {
                                label:   ["January","February","March","April","May","June","July","August","September","October","November","December"][root._navMonth] + " " + root._navYear
                                tooltip: "Right-click for today"
                                variant: root._pickerOpen ? "accent" : "text"
                                onClicked:      root._pickerOpen = !root._pickerOpen
                                onRightClicked: { root._resetNav(); root._pickerOpen = false }
                            }
                            Item { Layout.fillWidth: true }
                            IconButton {
                                label:   String.fromCodePoint(0xf105)
                                tooltip: root._pickerOpen ? "Next year" : "Next month"
                                onClicked: {
                                    if (root._pickerOpen) { root._navYear++ }
                                    else if (root._navMonth === 11) { root._navYear++; root._navMonth = 0 }
                                    else root._navMonth++
                                }
                            }
                        }

                        // Month/year picker — 3-col grid, shown when _pickerOpen
                        GridLayout {
                            Layout.fillWidth: true
                            visible:      root._pickerOpen
                            columns:      3
                            rowSpacing:   4
                            columnSpacing: 4

                            Repeater {
                                model: ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
                                PanelButton {
                                    Layout.fillWidth: true
                                    label:   modelData
                                    variant: index === root._navMonth ? "accent" : "default"
                                    onClicked: { root._navMonth = index; root._pickerOpen = false }
                                }
                            }
                        }

                        // Day headers (row 0) + day cells (rows 1–N) — one GridLayout
                        GridLayout {
                            Layout.fillWidth: true
                            visible:       !root._pickerOpen
                            columns:       7
                            columnSpacing: 0
                            rowSpacing:    2

                            Repeater {
                                model: ["M","T","W","T","F","S","S"]
                                Text {
                                    Layout.fillWidth:    true
                                    text:                modelData
                                    color:               index >= 5 ? Style.accentColor : Style.textMuted
                                    font.pixelSize:      Style.fontSizeSubtle
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            Repeater {
                                model: root._gridCells
                                Item {
                                    id: cellItem
                                    property var cell: modelData
                                    Layout.fillWidth: true
                                    implicitHeight:   22

                                    Rectangle {
                                        anchors.centerIn: parent; width: 20; height: 20; radius: Style.panelElementRadius
                                        color:   cellItem.cell.isToday ? Style.accentColor : "transparent"
                                        visible: cellItem.cell.day > 0
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text:  cellItem.cell.day > 0 ? cellItem.cell.day : ""
                                        color: cellItem.cell.isToday    ? Style.panelBgColor
                                             : cellItem.cell.hasContent ? Style.accentColor
                                             :                            Style.textSecondary
                                        font.pixelSize: Style.fontSizeSubtle
                                        font.weight:    cellItem.cell.isToday ? Font.Bold : Font.Normal
                                    }

                                    HoverHandler { id: cellHover }
                                    ToolTip {
                                        visible: cellHover.hovered && cellItem.cell.day > 0 && (cellItem.cell.events.length > 0 || cellItem.cell.tasks.length > 0)
                                        delay: 300
                                        contentItem: ColumnLayout {
                                            spacing: 2
                                            Repeater {
                                                model: cellItem.cell.events.slice(0, 4)
                                                Text { text: "• " + (modelData.summary || ""); color: Style.textMuted; font.pixelSize: Style.fontSizeBody }
                                            }
                                            Repeater {
                                                model: cellItem.cell.tasks.slice(0, 4)
                                                Text { text: "○ " + (modelData.title || ""); color: Style.textMuted; font.pixelSize: Style.fontSizeBody }
                                            }
                                        }
                                        background: Rectangle { color: Style.surfaceMidColor; border.color: Style.surfaceMidColor; radius: Style.panelElementRadius }
                                    }
                                }
                            }
                        }
                    }

                    // Column 2: action buttons (vertical sidebar)
                    ColumnLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignTop

                        IconButton {
                            label:   String.fromCodePoint(0xf021)
                            tooltip: "Refresh"
                            onClicked: {
                                if (root.calendarProcess) root.calendarProcess.refresh()
                                if (root.tasksProcess)    root.tasksProcess.refresh()
                            }
                        }

                        IconButton {
                            label:   String.fromCodePoint(0xf08e)
                            tooltip: "Open Google Calendar"
                            onClicked: Qt.openUrlExternally("https://calendar.google.com")
                        }
                    }
                }
            }

            // Events today
            PanelCard {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text:      "Events Today"
                        collapsed: root._eventsCollapsed
                        onToggled: root._eventsCollapsed = !root._eventsCollapsed
                    }

                    Item {
                        Layout.fillWidth: true
                        clip: true
                        Layout.preferredHeight: !root._eventsCollapsed ? _eventRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _eventRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            spacing: 6

                            Repeater {
                                model: calendarProcess ? calendarProcess.todayEvents.slice(0, 3) : []
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text {
                                        text: root._eventTime(modelData.start, modelData.allDay)
                                        color: Style.textMuted; font.pixelSize: Style.fontSizeBody
                                        Layout.preferredWidth: 52
                                    }
                                    ScrollingText {
                                        Layout.fillWidth: true
                                        text: modelData.summary || ""; color: Style.textNormal; font.pixelSize: Style.fontSizeBody
                                    }
                                }
                            }

                            Text {
                                visible: !calendarProcess || calendarProcess.todayEvents.length === 0
                                text: "No events today"; color: Style.textFaint; font.pixelSize: Style.fontSizeBody
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // Tasks today
            PanelCard {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text:      "Tasks Today"
                        collapsed: root._tasksCollapsed
                        onToggled: root._tasksCollapsed = !root._tasksCollapsed
                    }

                    Item {
                        Layout.fillWidth: true
                        clip: true
                        Layout.preferredHeight: !root._tasksCollapsed ? _taskRows.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            id: _taskRows
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            spacing: 6

                            Repeater {
                                model: tasksProcess ? tasksProcess.todayTasks.slice(0, 3) : []
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Text { text: "○"; color: Style.textMuted; font.pixelSize: root._navSize }
                                    ScrollingText {
                                        Layout.fillWidth: true
                                        text: modelData.title || ""; color: Style.textNormal; font.pixelSize: Style.fontSizeBody
                                    }
                                }
                            }

                            Text {
                                visible: !tasksProcess || tasksProcess.todayTasks.length === 0
                                text: "No tasks today"; color: Style.textFaint; font.pixelSize: Style.fontSizeBody
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Timer view ────────────────────────────────────────────────────────────
    Flickable {
        id: timerFlick
        anchors { left: parent.left; right: parent.right; top: _tabBar.bottom; bottom: parent.bottom }
        contentWidth:  width
        contentHeight: timerCol.implicitHeight + 24
        visible: root._view === "timer"
        flickableDirection: Flickable.VerticalFlick
        clip: true

        ColumnLayout {
            id: timerCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors { leftMargin: 12; rightMargin: 12; topMargin: 12 }
            spacing: 8

            PanelCard {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    SectionHeader {
                        Layout.fillWidth: true
                        text:      root.timerProcess && root.timerProcess.mode === "stopwatch" ? "Countup" : "Countdown"
                        collapsed: root._timerCollapsed
                        onToggled: root._timerCollapsed = !root._timerCollapsed
                    }

                    Item {
                        Layout.fillWidth: true
                        clip: true
                        Layout.preferredHeight: !root._timerCollapsed ? _timerWidget.implicitHeight + 8 : 0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        TimerWidget {
                            id: _timerWidget
                            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                            timerProcess:      root.timerProcess
                            focusReturnTarget: root
                        }
                    }
                }
            }
        }
    }

    // ── Expanded view ─────────────────────────────────────────────────────────
    Flickable {
        id: expandedFlick
        anchors { left: parent.left; right: parent.right; top: _tabBar.bottom; bottom: parent.bottom }
        contentWidth:  width
        contentHeight: expandedCol.implicitHeight + 24
        visible: root._view === "expanded"
        flickableDirection: Flickable.VerticalFlick
        clip: true

        ColumnLayout {
            id: expandedCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors { leftMargin: 12; rightMargin: 12; topMargin: 12 }
            spacing: 8

            // This week — events
            SectionLabel {
                text: "This Week"
                Layout.fillWidth: true; Layout.topMargin: 4
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: root._weekItems
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: modelData.type === "header" ? 18 : 16
                        property bool isHeader: modelData.type === "header"

                        Text {
                            visible: parent.isHeader
                            anchors.bottom: parent.bottom
                            text: modelData.label || ""
                            color: Style.textMuted; font.pixelSize: Style.fontSizeSubtle; font.weight: Font.Medium
                        }
                        RowLayout {
                            visible: !parent.isHeader
                            anchors.fill: parent; spacing: 6
                            Text {
                                text: root._eventTime(modelData.start, modelData.allDay)
                                color: Style.textMuted; font.pixelSize: Style.fontSizeBody
                                horizontalAlignment: Text.AlignLeft
                                Layout.preferredWidth: 90
                            }
                            ScrollingText {
                                Layout.fillWidth: true
                                height: parent.height
                                text: modelData.summary || ""
                                color: Style.textNormal
                                font.pixelSize: Style.fontSizeBody
                            }
                        }
                    }
                }
            }
            Text {
                visible: !calendarProcess || calendarProcess.weekEvents.length === 0
                text: "No events this week"; color: Style.textFaint; font.pixelSize: Style.fontSizeBody
                Layout.fillWidth: true
            }

            // This week — tasks
            SectionLabel {
                text: "Tasks This Week"
                Layout.fillWidth: true; Layout.topMargin: 4
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: root._weekTaskItems
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: modelData.type === "header" ? 18 : 16
                        property bool isHeader: modelData.type === "header"

                        Text {
                            visible: parent.isHeader
                            anchors.bottom: parent.bottom
                            text: modelData.label || ""
                            color: Style.textMuted; font.pixelSize: Style.fontSizeSubtle; font.weight: Font.Medium
                        }
                        RowLayout {
                            visible: !parent.isHeader
                            anchors.fill: parent; spacing: 6
                            Text { text: "○"; color: Style.textMuted; font.pixelSize: root._navSize }
                            ScrollingText {
                                Layout.fillWidth: true
                                height: parent.height
                                text: modelData.title || ""
                                color: Style.textNormal
                                font.pixelSize: Style.fontSizeBody
                            }
                        }
                    }
                }
            }
            Text {
                visible: !tasksProcess || tasksProcess.weekTasks.length === 0
                text: "No tasks this week"; color: Style.textFaint; font.pixelSize: Style.fontSizeBody
                Layout.fillWidth: true
            }

            // 7-day forecast
            SectionLabel {
                text: "7-Day Forecast"
                Layout.fillWidth: true; Layout.topMargin: 4
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: weatherProcess ? weatherProcess.forecast : []
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: root._dayLabel(modelData.date)
                            color: Style.textMuted; font.pixelSize: Style.fontSizeBody
                            Layout.preferredWidth: 70
                        }
                        Text {
                            text: String.fromCharCode(parseInt(modelData.icon, 16))
                            color: Style.textMuted; font.family: Style.fontNerd; font.pixelSize: Style.fontSizeHeading
                            Layout.preferredWidth: 20; horizontalAlignment: Text.AlignHCenter
                        }
                        ScrollingText {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            text: modelData.condition
                            color: Style.textMuted
                            font.pixelSize: Style.fontSizeBody
                        }
                        Text {
                            text: modelData.high + "° / " + modelData.low + "°"
                            color: Style.textNormal; font.pixelSize: Style.fontSizeBody
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }
            }
        }
    }
}
