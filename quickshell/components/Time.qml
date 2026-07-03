import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io

// Panel-only: the pill row itself lives in TimePill.qml, rolled by the
// shared bar in shell.qml.  This component is just the expanded calendar
// panel, anchored directly below the bar. `hovered` and `pinned` are fed in
// externally from shell.qml's root-level combined-region hover/pin state
// (not local to this instance, since it gets destroyed/recreated whenever
// another module briefly takes over the bar). `events` is bound to
// shell.qml's `calendarEvents`, populated by the periodic `gcal-fetch`
// Process — see gcal_fetch.py for the {id, summary, start, end, allDay,
// htmlLink} shape.
Item {
    id: root

    property bool hovered: false
    property bool pinned: false
    property var  events: []

    signal dismissRequested()

    implicitWidth: parent ? parent.width : 0
    readonly property int calendarGap: Math.round(Screen.height * 0.01)
    implicitHeight: (hovered || pinned) ? calendarGap + calendarPanel.implicitHeight : 0

    // ── Today's agenda ─────────────────────────────────────────────────────
    function _dateKey(d) { return Qt.formatDate(d, "yyyy-MM-dd") }
    readonly property string _todayKey: _dateKey(new Date())
    readonly property var _todayEvents: root.events.filter(function(e) {
        return (e.allDay ? e.start : _dateKey(new Date(e.start))) === root._todayKey
    })
    readonly property var _allDayEvents: _todayEvents.filter(function(e) { return e.allDay })
    readonly property var _timedEvents:  _todayEvents.filter(function(e) { return !e.allDay })

    // ── Month view navigation ────────────────────────────────────────────
    property int viewYear:  new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    // Month/year picker replaces the grid inline (rather than a floating
    // Popup) — this is a fixed-size Wayland layer-shell surface, so there's
    // no "outside the window" for an overlay to render into; everything has
    // to stay within the panel's own (already auto-sizing) bounds.
    property bool _pickerOpen: false

    function _shiftMonth(delta) {
        var m = root.viewMonth + delta, y = root.viewYear
        while (m < 0)  { m += 12; y-- }
        while (m > 11) { m -= 12; y++ }
        root.viewMonth = m
        root.viewYear  = y
    }

    // {y, m (0-based), d} parsed without going through a JS Date for allDay
    // events — new Date("yyyy-MM-dd") parses as UTC midnight, which can
    // shift to the previous local day west of UTC.
    function _ymdOf(ev) {
        if (ev.allDay) {
            var p = ev.start.split("-")
            return { y: parseInt(p[0]), m: parseInt(p[1]) - 1, d: parseInt(p[2]) }
        }
        var dt = new Date(ev.start)
        return { y: dt.getFullYear(), m: dt.getMonth(), d: dt.getDate() }
    }

    // Event summaries for the currently-navigated month, keyed by day-of-month.
    readonly property var _monthEventsByDay: {
        var map = {}
        for (var i = 0; i < root.events.length; i++) {
            var ymd = root._ymdOf(root.events[i])
            if (ymd.y !== root.viewYear || ymd.m !== root.viewMonth) continue
            if (!map[ymd.d]) map[ymd.d] = []
            map[ymd.d].push(root.events[i].summary)
        }
        return map
    }

    Rectangle {
        id: calendarPanel
        anchors.top: parent.top
        anchors.topMargin: root.calendarGap
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        color: Style.panelBg
        radius: Style.panelRadius
        border.width: Style.panelBorderWidth
        border.color: Style.panelBorder
        implicitHeight: contentLayout.implicitHeight + 16

        ColumnLayout {
            id: contentLayout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }
            spacing: 8

            // Always reserved so pinning doesn't resize the panel — only the
            // button's own visibility toggles within this constant-height row.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                PinButton {
                    visible: root.pinned
                    onClicked: root.dismissRequested()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // ── Agenda (left) ────────────────────────────────────────
                ColumnLayout {
                    Layout.preferredWidth: calendarPanel.width * 0.28
                    Layout.fillHeight: true
                    spacing: 6

                    Text {
                        text: Qt.formatDate(new Date(), "ddd d MMM")
                        color: Style.textPanelHighlight
                        font.family: Style.fontFamily
                        font.pointSize: Style.fontSize
                        font.bold: true
                    }

                    Repeater {
                        model: root._allDayEvents
                        delegate: Text {
                            id: allDayText
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.summary
                            color: Style.textPanelNormal
                            font.family: Style.fontFamily
                            font.pointSize: Style.fontSize
                            elide: Text.ElideRight

                            HoverHandler { id: allDayHover }
                            PanelToolTip {
                                visible: allDayHover.hovered && allDayText.truncated
                                text: allDayText.text
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                        height: 1
                        color: Style.panelBorder
                        visible: root._allDayEvents.length > 0 && root._timedEvents.length > 0
                    }

                    Repeater {
                        model: root._timedEvents
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: Qt.formatTime(new Date(modelData.start), "HH:mm")
                                color: Style.textPanelHighlight
                                font.family: Style.fontFamily
                                font.pointSize: Style.fontSize
                            }
                            Text {
                                id: timedText
                                Layout.fillWidth: true
                                text: modelData.summary
                                color: Style.textPanelNormal
                                font.family: Style.fontFamily
                                font.pointSize: Style.fontSize
                                elide: Text.ElideRight

                                HoverHandler { id: timedHover }
                                PanelToolTip {
                                    visible: timedHover.hovered && timedText.truncated
                                    text: timedText.text
                                }
                            }
                        }
                    }

                    Text {
                        visible: root._todayEvents.length === 0
                        text: "No events today"
                        color: Style.textPanelLow
                        font.family: Style.fontFamily
                        font.pointSize: Style.fontSize
                    }

                    Item { Layout.fillHeight: true }
                }

                // ── Month view + weather (middle) ────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // ── Month nav: prev triangle / picker button / next triangle ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            PanelIconButton {
                                icon: "◀"
                                onClicked: root._shiftMonth(-1)
                            }

                            // Center button — same visual language as Mpris.qml's
                            // focus button (rectangle, hover-grow, drop shadow),
                            // but centered text and no icon, per the sketch.
                            // Sized to match PanelIconButton (26/30, fixed 30
                            // footprint) so it lines up with the triangle
                            // buttons on either side instead of Mpris' own
                            // pillHeight-based sizing (24/28).
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 30

                                Rectangle {
                                    id: monthYearBtn
                                    property bool localHovered: false
                                    anchors.centerIn: parent
                                    width: localHovered ? parent.width + 4 : parent.width
                                    height: localHovered ? 30 : 26
                                    color: Style.panelButtonBg
                                    radius: Style.panelButtonRadius
                                    border.width: Style.panelButtonBorderWidth
                                    border.color: Style.panelButtonBorder
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Style.panelButtonShadowColor
                                        shadowBlur: monthYearBtn.localHovered ? Style.panelButtonShadowBlurHover : Style.panelButtonShadowBlurRest
                                        shadowVerticalOffset: monthYearBtn.localHovered ? Style.panelButtonShadowVerticalOffsetHover : Style.panelButtonShadowVerticalOffsetRest
                                        shadowOpacity: monthYearBtn.localHovered ? Style.panelButtonShadowOpacityHover : Style.panelButtonShadowOpacityRest
                                    }

                                    HoverHandler { onHoveredChanged: monthYearBtn.localHovered = hovered }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root._pickerOpen) {
                                                // "Today" shortcut while the picker is open —
                                                // jumps back to the current month and closes
                                                // the picker, without needing W-1 again.
                                                root.viewYear  = new Date().getFullYear()
                                                root.viewMonth = new Date().getMonth()
                                                root._pickerOpen = false
                                            } else {
                                                root._pickerOpen = true
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root._pickerOpen ? "Today"
                                            : Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                                        horizontalAlignment: Text.AlignHCenter
                                        color: Style.textPanelHighlight
                                        font.family: Style.fontFamily
                                        font.pointSize: Style.fontSize
                                    }
                                }
                            }

                            PanelIconButton {
                                icon: "▶"
                                onClicked: root._shiftMonth(1)
                            }
                        }

                        DayOfWeekRow {
                            Layout.fillWidth: true
                            visible: !root._pickerOpen

                            delegate: Text {
                                required property string shortName
                                text: shortName
                                horizontalAlignment: Text.AlignHCenter
                                color: Style.textPanelHighlight
                                font.family: Style.fontFamily
                                font.pointSize: 11
                            }
                        }

                        MonthGrid {
                            id: monthGrid
                            Layout.fillWidth: true
                            visible: !root._pickerOpen
                            month: root.viewMonth
                            year: root.viewYear

                            delegate: Item {
                                id: dayCell
                                required property int day
                                required property int month
                                required property bool today

                                readonly property var _dayEvents:
                                    dayCell.month === monthGrid.month ? (root._monthEventsByDay[dayCell.day] || []) : []
                                property bool _todayHovered: false

                                implicitWidth: dayText.implicitWidth + 6
                                implicitHeight: dayText.implicitHeight + 4

                                // Today gets the "button effect" — same hover-grow +
                                // shadow language as PanelIconButton/PinButton — while
                                // this Item's own size stays fixed so MonthGrid's
                                // internal cell layout doesn't shift on hover.
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: dayCell.today
                                    width:  (dayCell._todayHovered ? parent.width  + 6 : parent.width  + 2)
                                    height: (dayCell._todayHovered ? parent.height + 6 : parent.height + 2)
                                    color: Style.panelButtonBg
                                    radius: Style.panelButtonRadius
                                    border.width: Style.panelButtonBorderWidth
                                    border.color: Style.panelButtonBorder
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Style.panelButtonShadowColor
                                        shadowBlur: dayCell._todayHovered ? Style.panelButtonShadowBlurHover : Style.panelButtonShadowBlurRest
                                        shadowVerticalOffset: dayCell._todayHovered ? Style.panelButtonShadowVerticalOffsetHover : Style.panelButtonShadowVerticalOffsetRest
                                        shadowOpacity: dayCell._todayHovered ? Style.panelButtonShadowOpacityHover : Style.panelButtonShadowOpacityRest
                                    }
                                }

                                Text {
                                    id: dayText
                                    anchors.centerIn: parent
                                    text: dayCell.day
                                    horizontalAlignment: Text.AlignHCenter
                                    color: dayCell._dayEvents.length > 0 ? Style.textPanelHighlight
                                         : dayCell.month === monthGrid.month ? Style.textPanelNormal
                                         : Style.textPanelLow
                                    font.family: Style.fontFamily
                                    font.pointSize: 11
                                    font.bold: dayCell.today
                                }

                                // Today's button-grow hover.
                                HoverHandler {
                                    enabled: dayCell.today
                                    onHoveredChanged: dayCell._todayHovered = hovered
                                }

                                // Event tooltip — any day with events, today included.
                                HoverHandler { id: eventHover }
                                PanelToolTip {
                                    visible: eventHover.hovered && dayCell._dayEvents.length > 0
                                    text: dayCell._dayEvents.join("\n")
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: dayCell.today
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.viewYear  = new Date().getFullYear()
                                        root.viewMonth = new Date().getMonth()
                                    }
                                }
                            }
                        }

                        // ── Month/year picker — replaces the grid inline when open ──
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root._pickerOpen
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                PanelIconButton {
                                    icon: "◀"
                                    onClicked: root.viewYear--
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.viewYear
                                    color: Style.textPanelHighlight
                                    font.family: Style.fontFamily
                                    font.pointSize: Style.fontSize
                                    font.bold: true
                                }
                                PanelIconButton {
                                    icon: "▶"
                                    onClicked: root.viewYear++
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                columnSpacing: 6
                                rowSpacing: 6

                                Repeater {
                                    model: 12
                                    delegate: Rectangle {
                                        id: monthCell
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 26
                                        property bool localHovered: false
                                        color: index === root.viewMonth ? Style.textPanelHighlight
                                             : localHovered ? Style.panelButtonBg : "transparent"
                                        radius: Style.panelButtonRadius
                                        border.width: Style.panelButtonBorderWidth
                                        border.color: Style.panelButtonBorder

                                        HoverHandler { onHoveredChanged: monthCell.localHovered = hovered }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.viewMonth = monthCell.index
                                                root._pickerOpen = false
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: Qt.locale().monthName(monthCell.index, Locale.ShortFormat)
                                            color: monthCell.index === root.viewMonth ? Style.textPanelOnHighlight : Style.textPanelNormal
                                            font.family: Style.fontFamily
                                            font.pointSize: Style.fontSize
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Placeholder — no weather source wired up yet.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        color: Style.panelButtonBg
                        radius: Style.panelButtonRadius
                        border.width: Style.panelButtonBorderWidth
                        border.color: Style.panelButtonBorder

                        Text {
                            anchors.centerIn: parent
                            text: "weather — not wired up yet"
                            color: Style.textPanelLow
                            font.family: Style.fontFamily
                            font.pointSize: Style.fontSize
                        }
                    }
                }

                // ── Button rail (right) ──────────────────────────────────
                // Bottom-aligned so it sits next to the weather box (the
                // last element in the middle column) rather than up by the
                // month grid header.
                ColumnLayout {
                    Layout.alignment: Qt.AlignBottom
                    spacing: 8

                    PanelIconButton {
                        icon: String.fromCharCode(0xf013)  // gear
                        // No-op until the Settings component (roadmap item) exists.
                        onClicked: {}
                    }
                    PanelIconButton {
                        icon: String.fromCharCode(0xf0ac)  // globe
                        tooltip: "Open in browser"
                        onClicked: openCalendarProcess.running = true
                    }
                    PanelIconButton {
                        icon: String.fromCharCode(0xf141)  // ellipsis — reserved, TBD
                        onClicked: {}
                    }
                }
            }
        }
    }

    Process {
        id: openCalendarProcess
        command: ["xdg-open", "https://calendar.google.com/"]
    }
}
