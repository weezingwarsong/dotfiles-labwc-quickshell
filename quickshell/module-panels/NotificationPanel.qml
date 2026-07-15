import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell.Services.Notifications

Item {
    id: root

    property var    notificationServer: null
    property var    screenshotProcess:  null
    property string activePanel:        ""
    signal navigateRequested(int direction)

    property int _tab: 0   // 0 = Notifications, 1 = Screenshots

    readonly property bool _hasNotifs: notificationServer && notificationServer.countTotal > 0
    readonly property var  _shots:     screenshotProcess  ? screenshotProcess.screenshots  : []

    implicitHeight: _topFixed.implicitHeight
                  + _body.implicitHeight
                  + (_trayBar.count > 0 ? (1 + 24 + Style.panelMargin) : 0)
                  + Style.panelMargin * 3 + 24

    // ── Background ────────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill:  parent
        radius:        Style.panelRadius
        color:         Style.panelBgColor
        border.color:  Style.panelBorderColor
        border.width:  1
        clip:          true
    }

    // ── Fixed top section ─────────────────────────────────────────────────────

    ColumnLayout {
        id: _topFixed
        anchors {
            top:         parent.top
            left:        parent.left
            right:       parent.right
            topMargin:   Style.panelMargin
            leftMargin:  Style.panelMargin
            rightMargin: Style.panelMargin
        }
        spacing: 8

        PanelNavBar {
            Layout.fillWidth: true
            activePanel: root.activePanel
            onNavigateRequested: (dir) => root.navigateRequested(dir)
        }

        PanelTabBar {
            Layout.fillWidth: true
            labels:   ["Notifications", "Screenshots"]
            selected: root._tab
            onToggled: (idx) => root._tab = idx
        }

        // Clear all — only on notifications tab and only when there are notifs
        PanelButton {
            Layout.alignment: Qt.AlignRight
            visible:   root._tab === 0 && root._hasNotifs
            variant:   "critical"
            label:     "Clear all"
            onClicked: root.notificationServer && root.notificationServer.clearAll()
        }
    }

    // ── Body — swaps between notification list and screenshots list ───────────

    Item {
        id: _body
        anchors {
            top:          _topFixed.bottom
            left:         parent.left
            right:        parent.right
            bottom:       _sysDivider.top
            topMargin:    8
            leftMargin:   Style.panelMargin
            rightMargin:  Style.panelMargin
            bottomMargin: Style.panelMargin
        }
        implicitHeight: Math.max(_notifFlick.implicitHeight, _shotFlick.implicitHeight)

        // ── Notifications ─────────────────────────────────────────────────────

        Item {
            anchors.fill: parent
            visible: root._tab === 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:        16
                visible:                  !root._hasNotifs
                text:                     "No notifications"
                color:                    Style.textMuted
                font.family:              Style.fontMono
                font.pixelSize:           Style.fontSizeBody
            }

            Flickable {
                id: _notifFlick
                anchors.fill:  parent
                visible:       root._hasNotifs
                contentHeight: _cardCol.implicitHeight
                clip:          true
                implicitHeight: _cardCol.implicitHeight

                ColumnLayout {
                    id:      _cardCol
                    width:   parent.width
                    spacing: 6

                    Repeater {
                        model: root.notificationServer ? root.notificationServer.notifications : null

                        delegate: Rectangle {
                            id: _card

                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight:   _cardRow.implicitHeight + 16

                            radius:       Style.panelElementRadius
                            border.width: Style.elementBorderWidth
                            border.color: Style.borderFaintColor

                            color: {
                                var u = _card.modelData.urgency
                                if (u === NotificationUrgency.Critical)
                                    return Qt.rgba(Style.mat3Error.r, Style.mat3Error.g, Style.mat3Error.b, 0.15)
                                if (u === NotificationUrgency.Low)
                                    return Style.surfaceLowColor
                                return Style.surfaceMidColor
                            }

                            property bool _expanded: false

                            readonly property var _labeledActions: {
                                var acts = _card.modelData.actions
                                if (!acts) return []
                                var result = []
                                for (var i = 0; i < acts.length; i++) {
                                    if (acts[i].identifier !== "default") result.push(acts[i])
                                }
                                return result
                            }

                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: _card.modelData.dismiss()
                            }

                            RowLayout {
                                id:      _cardRow
                                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                                spacing: 8

                                Rectangle {
                                    visible:                _card.modelData.image !== ""
                                    Layout.preferredWidth:  56
                                    Layout.preferredHeight: 56
                                    Layout.alignment:       Qt.AlignTop
                                    radius:                 Style.panelElementRadius
                                    color:                  Style.surfaceLowColor
                                    clip:                   true

                                    Image {
                                        anchors.fill: parent
                                        source:       _card.modelData.image || ""
                                        fillMode:     Image.PreserveAspectCrop
                                        visible:      status === Image.Ready
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text:           _card.modelData.appName || ""
                                            color:          Style.textMuted
                                            font.family:    Style.fontMono
                                            font.pixelSize: Style.fontSizeSubtle
                                            elide:          Text.ElideRight
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                        }

                                        Text {
                                            property var _ts: root.notificationServer
                                                ? root.notificationServer.getTimestamp(_card.modelData.id)
                                                : null
                                            text:           _ts ? Qt.formatTime(_ts, "hh:mm") : ""
                                            color:          Style.textMuted
                                            font.family:    Style.fontMono
                                            font.pixelSize: Style.fontSizeSubtle
                                            visible:        text !== ""
                                        }

                                        Rectangle {
                                            width:  Style.buttonHeight - 4
                                            height: Style.buttonHeight - 4
                                            radius: Style.panelElementRadius
                                            color:  _xHover.hovered ? Style.surfaceLowColor : Style.transparent

                                            Text {
                                                anchors.centerIn: parent
                                                text:           "×"
                                                color:          Style.textMuted
                                                font.family:    Style.fontMono
                                                font.pixelSize: Style.fontSizeBody
                                            }

                                            HoverHandler { id: _xHover; cursorShape: Qt.PointingHandCursor }
                                            TapHandler   { onTapped: _card.modelData.dismiss() }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text:           _card.modelData.summary || ""
                                        color:          Style.textNormal
                                        font.family:    Style.fontMono
                                        font.pixelSize: Style.fontSizeBody
                                        wrapMode:       Text.WordWrap
                                        visible:        text !== ""
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text:           _card.modelData.body || ""
                                        color:          Style.textSecondary
                                        font.family:    Style.fontMono
                                        font.pixelSize: Style.fontSizeSubtle
                                        wrapMode:       Text.WordWrap
                                        visible:        text !== ""
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        visible: _card._labeledActions.length > 0

                                        Repeater {
                                            model: Math.min(_card._labeledActions.length, 2)
                                            delegate: PanelButton {
                                                required property int index
                                                property var _action: _card._labeledActions[index]

                                                Layout.fillWidth:  true
                                                label:             _action ? _action.text : ""
                                                QQC.ToolTip.text:  _action ? _action.text : ""
                                                QQC.ToolTip.visible: _hover2.hovered && implicitWidth > width + 4
                                                QQC.ToolTip.delay: 600

                                                HoverHandler { id: _hover2 }

                                                onClicked: {
                                                    if (_action) _action.invoke()
                                                    _card.modelData.dismiss()
                                                }
                                            }
                                        }

                                        IconButton {
                                            visible:   _card._labeledActions.length > 2
                                            label:     "⋮"
                                            fontFamily: Style.fontMono
                                            onClicked: _card._expanded = !_card._expanded
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        visible: _card._expanded && _card._labeledActions.length > 2

                                        Repeater {
                                            model: Math.min(_card._labeledActions.length - 2, 2)
                                            delegate: PanelButton {
                                                required property int index
                                                property var _action: _card._labeledActions[index + 2]

                                                Layout.fillWidth:  true
                                                label:             _action ? _action.text : ""
                                                QQC.ToolTip.text:  _action ? _action.text : ""
                                                QQC.ToolTip.visible: _hover3.hovered && implicitWidth > width + 4
                                                QQC.ToolTip.delay: 600

                                                HoverHandler { id: _hover3 }

                                                onClicked: {
                                                    if (_action) _action.invoke()
                                                    _card.modelData.dismiss()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Screenshots ───────────────────────────────────────────────────────

        Item {
            anchors.fill: parent
            visible: root._tab === 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top:              parent.top
                anchors.topMargin:        16
                visible:                  root._shots.length === 0
                text:                     "No screenshots"
                color:                    Style.textMuted
                font.family:              Style.fontMono
                font.pixelSize:           Style.fontSizeBody
            }

            Flickable {
                id: _shotFlick
                anchors.fill:  parent
                visible:       root._shots.length > 0
                contentHeight: _shotCol.implicitHeight
                clip:          true
                implicitHeight: _shotCol.implicitHeight

                ColumnLayout {
                    id:      _shotCol
                    width:   parent.width
                    spacing: 6

                    Repeater {
                        model: root._shots

                        delegate: Rectangle {
                            id: _shotCard

                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight:   _shotRow.implicitHeight + 16

                            radius:       Style.panelElementRadius
                            border.width: Style.elementBorderWidth
                            border.color: Style.borderFaintColor
                            color:        Style.surfaceLowColor

                            RowLayout {
                                id: _shotRow
                                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                                spacing: 8

                                MediaThumbnail {
                                    source:   _shotCard.modelData.path
                                    filename: ""
                                    Layout.preferredWidth: 72
                                    onThumbnailClicked: _xdgOpen.running = true

                                    Process {
                                        id: _xdgOpen
                                        command: ["xdg-open", _shotCard.modelData.path]
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth:  true
                                    Layout.alignment:  Qt.AlignTop
                                    spacing: 3

                                    Text {
                                        text:           _shotCard.modelData.name
                                        color:          Style.textNormal
                                        font.family:    Style.fontMono
                                        font.pixelSize: Style.fontSizeSubtle
                                        elide:          Text.ElideMiddle
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text:           Qt.formatTime(new Date(_shotCard.modelData.timestamp), "hh:mm:ss")
                                        color:          Style.textMuted
                                        font.family:    Style.fontMono
                                        font.pixelSize: Style.fontSizeSubtle
                                    }

                                    RowLayout {
                                        spacing: 4

                                        PanelButton {
                                            label: "Open"
                                            onClicked: _xdgOpen.running = true
                                        }

                                        PanelButton {
                                            label: "Copy"
                                            onClicked: _copyImg.running = true

                                            Process {
                                                id: _copyImg
                                                command: ["sh", "-c", "wl-copy -t image/png < \"$1\"", "sh", _shotCard.modelData.path]
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Systray footer ────────────────────────────────────────────────────────

    Rectangle {
        id: _sysDivider
        anchors { bottom: _trayBar.top; left: parent.left; right: parent.right }
        height: _trayBar.count > 0 ? 1 : 0
        color:  Style.panelBorderColor
    }

    SysTrayBar {
        id: _trayBar
        anchors {
            bottom:       parent.bottom
            bottomMargin: _trayBar.count > 0 ? Style.panelMargin : 0
            right:        parent.right
            rightMargin:  Style.panelMargin
        }
        height: _trayBar.count > 0 ? 24 : 0
    }
}
