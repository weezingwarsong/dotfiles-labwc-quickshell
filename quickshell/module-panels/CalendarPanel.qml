import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import Quickshell

Item {
    id: root

    // ── Injected processes ────────────────────────────────────────────────────
    property var clockProcess:    null
    property var calendarProcess: null
    property var tasksProcess:    null
    property var weatherProcess:  null
    property var timerProcess:    null

    // ── View state ────────────────────────────────────────────────────────────
    property string _view: "glance"  // "glance" | "expanded" | "timer"

    property string activePanel: ""
    signal navigateRequested(int direction)

    // Nav arrows and task bullets — fixed at 11px (between body and heading)
    readonly property int _navSize: 11

    // Content height for the active view — PanelSurface reads this to size the window.
    // +24 accounts for anchors.margins: 12 on each ColumnLayout (top + bottom).
    implicitHeight: {
        if (_view === "glance")   return glanceFlick.contentHeight   + 24
        if (_view === "expanded") return expandedFlick.contentHeight  + 24
        if (_view === "timer")    return timerFlick.contentHeight     + 24
        return 0
    }

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

    // ── Root visual container ─────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: Style.radLg
        color: Style.panelBgColor
        border.color: Style.panelBorderColor
        border.width: 1
        clip: true

        // ── Glance view ───────────────────────────────────────────────────────
        Flickable {
            id: glanceFlick
            anchors.fill: parent
            contentHeight: glanceCol.implicitHeight
            visible: root._view === "glance"
            flickableDirection: Flickable.VerticalFlick
            clip: true

            ColumnLayout {
                id: glanceCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                PanelNavBar { activePanel: root.activePanel; onNavigateRequested: (dir) => root.navigateRequested(dir) }

                // Date + weather row
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
                    text: weatherProcess && weatherProcess.current ? weatherProcess.current.condition + "  " + weatherProcess.current.high + "° / " + weatherProcess.current.low + "°" : ""
                    color: Style.textMuted; font.pixelSize: Style.fontSizeSubtle
                    Layout.fillWidth: true
                }

                // Month navigation
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Text {
                        text: "‹"; color: Style.textMuted; font.pixelSize: root._navSize; font.weight: Font.Bold
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            onClicked: {
                                if (root._navMonth === 0) { root._navYear--; root._navMonth = 11 }
                                else root._navMonth--
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: ["January","February","March","April","May","June","July","August","September","October","November","December"][root._navMonth] + " " + root._navYear
                        color: Style.textNormal; font.pixelSize: Style.fontSizeBody; font.weight: Font.Medium
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "›"; color: Style.textMuted; font.pixelSize: root._navSize; font.weight: Font.Bold
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
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 0
                    Repeater {
                        model: ["M","T","W","T","F","S","S"]
                        Text {
                            text: modelData
                            color: index >= 5 ? Style.accentColor : Style.textMuted
                            font.pixelSize: Style.fontSizeSubtle
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }
                }

                // Month grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 0
                    rowSpacing: 4
                    Layout.topMargin: 2
                    Repeater {
                        model: root._gridCells
                        Item {
                            id: cellItem
                            property var cell: modelData  // capture before inner Repeaters shadow it
                            Layout.fillWidth: true
                            implicitHeight: 20

                            Rectangle {
                                anchors.centerIn: parent; width: 16; height: 16; radius: Style.radMd
                                color: cellItem.cell.isToday ? Style.accentColor : "transparent"
                                visible: cellItem.cell.day > 0
                            }
                            Text {
                                anchors.centerIn: parent
                                text: cellItem.cell.day > 0 ? cellItem.cell.day : ""
                                color: cellItem.cell.isToday ? Style.panelBgColor : Style.textSecondary
                                font.pixelSize: Style.fontSizeSubtle
                                font.weight: cellItem.cell.isToday ? Font.Bold : Font.Normal
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: 3; height: 3; radius: 1.5
                                color: Style.accentColor
                                visible: cellItem.cell.day > 0 && cellItem.cell.hasContent
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
                                background: Rectangle {
                                    color: Style.surfaceMidColor; border.color: Style.surfaceMidColor; radius: Style.radMd
                                }
                            }
                        }
                    }
                }

                // Refresh button — bottom-right of month grid
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 14

                    Text {
                        id: _refreshBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: _refreshHover.hovered ? Style.textNormal : Style.textMuted
                        font.family: Style.fontNerd
                        font.pixelSize: root._navSize

                        HoverHandler { id: _refreshHover }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.calendarProcess) root.calendarProcess.refresh()
                                if (root.tasksProcess)    root.tasksProcess.refresh()
                            }
                        }
                        ToolTip {
                            visible: _refreshHover.hovered
                            delay: 300
                            text: "Refresh"
                        }
                    }
                }

                PanelDivider { Layout.topMargin: 4 }

                // Events today
                SectionLabel {
                    text: "Events Today"
                    Layout.fillWidth: true; Layout.topMargin: 4
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: calendarProcess ? calendarProcess.todayEvents.slice(0, 3) : []
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                text: root._eventTime(modelData.start, modelData.allDay)
                                color: Style.textMuted; font.pixelSize: Style.fontSizeBody
                                Layout.preferredWidth: 38
                            }
                            Text {
                                text: modelData.summary || ""
                                color: Style.textNormal; font.pixelSize: Style.fontSizeBody; elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
                Text {
                    visible: !calendarProcess || calendarProcess.todayEvents.length === 0
                    text: "No events today"; color: Style.textFaint; font.pixelSize: Style.fontSizeBody
                    Layout.fillWidth: true
                }

                // Tasks today
                SectionLabel {
                    text: "Tasks Today"
                    Layout.fillWidth: true; Layout.topMargin: 4
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: tasksProcess ? tasksProcess.todayTasks.slice(0, 3) : []
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text { text: "○"; color: Style.textMuted; font.pixelSize: root._navSize }
                            Text {
                                text: modelData.title || ""
                                color: Style.textNormal; font.pixelSize: Style.fontSizeBody; elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
                Text {
                    visible: !tasksProcess || tasksProcess.todayTasks.length === 0
                    text: "No tasks today"; color: Style.textFaint; font.pixelSize: Style.fontSizeBody
                    Layout.fillWidth: true
                }

                PanelDivider { Layout.topMargin: 4 }

                // Footer actions
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6
                    PanelButton {
                        Layout.fillWidth: true
                        label: "More ↓"
                        onClicked: root._view = "expanded"
                    }
                    PanelButton {
                        Layout.fillWidth: true
                        label: "Timer"
                        onClicked: root._view = "timer"
                    }
                    PanelButton {
                        Layout.fillWidth: true
                        label: "Edit ↗"
                        onClicked: Qt.openUrlExternally("https://calendar.google.com")
                    }
                }
            }
        }

        // ── Timer view ───────────────────────────────────────────────────────
        Flickable {
            id: timerFlick
            anchors.fill: parent
            contentHeight: timerCol.implicitHeight
            visible: root._view === "timer"
            flickableDirection: Flickable.VerticalFlick
            clip: true

            ColumnLayout {
                id: timerCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                PanelNavBar { activePanel: root.activePanel; onNavigateRequested: (dir) => root.navigateRequested(dir) }

                Text {
                    text: "↑ Back"
                    color: Style.accentColor; font.pixelSize: root._navSize
                    Layout.fillWidth: true
                    MouseArea { anchors.fill: parent; onClicked: root._view = "glance" }
                }

                TimerWidget {
                    Layout.fillWidth: true
                    timerProcess: root.timerProcess
                }
            }
        }

        // ── Expanded view ─────────────────────────────────────────────────────
        Flickable {
            id: expandedFlick
            anchors.fill: parent
            contentHeight: expandedCol.implicitHeight
            visible: root._view === "expanded"
            flickableDirection: Flickable.VerticalFlick
            clip: true

            ColumnLayout {
                id: expandedCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                PanelNavBar { activePanel: root.activePanel; onNavigateRequested: (dir) => root.navigateRequested(dir) }

                Text {
                    text: "↑ Back"
                    color: Style.accentColor; font.pixelSize: root._navSize
                    Layout.fillWidth: true
                    MouseArea { anchors.fill: parent; onClicked: root._view = "glance" }
                }

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
                                    Layout.preferredWidth: 38
                                }
                                Text {
                                    text: modelData.summary || ""
                                    color: Style.textNormal; font.pixelSize: Style.fontSizeBody; elide: Text.ElideRight
                                    Layout.fillWidth: true
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
                                Text {
                                    text: modelData.title || ""
                                    color: Style.textNormal; font.pixelSize: Style.fontSizeBody; elide: Text.ElideRight
                                    Layout.fillWidth: true
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
                                Layout.preferredWidth: 56
                            }
                            Text {
                                text: String.fromCharCode(parseInt(modelData.icon, 16))
                                color: Style.textMuted; font.family: Style.fontNerd; font.pixelSize: Style.fontSizeHeading
                            }
                            Text {
                                text: modelData.condition
                                color: Style.textMuted; font.pixelSize: Style.fontSizeBody; elide: Text.ElideRight
                                Layout.fillWidth: true
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
}
