import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell.Services.Notifications
import Quickshell.Io

Item {
    id: root
    focus: true

    property var notificationServer:     null
    property var screenshotProcess:      null
    property int notificationInitialTab: 0

    property string hoveredShotPath: ""

    property int _tab: notificationInitialTab

    Keys.onTabPressed: (event) => {
        root._tab = root._tab === 0 ? 1 : 0
        event.accepted = true
    }

    readonly property bool _hasNotifs: notificationServer && notificationServer.countTotal > 0
    readonly property var  _shots:     screenshotProcess  ? screenshotProcess.screenshots : []

    implicitHeight: _topFixed.implicitHeight
                  + Style.panelCardVpadding
                  + _flickCol.implicitHeight
                  + (_trayBar.count > 0
                      ? Style.panelElementVpadding + 1 + Style.panelElementVpadding + 24 + Style.panelMargin
                      : 0)

    // ── Fixed top section ─────────────────────────────────────────────────────

    ColumnLayout {
        id: _topFixed
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: Style.panelCardVpadding

        PanelTabBar {
            Layout.fillWidth: true
            labels:   ["Notifications", "Screenshots"]
            selected: root._tab
            onToggled: (idx) => root._tab = idx
        }

        PanelButton {
            Layout.alignment: Qt.AlignRight
            visible:   root._tab === 0 && root._hasNotifs
            variant:   "critical"
            label:     "Clear all"
            onClicked: root.notificationServer && root.notificationServer.clearAll()
        }
    }

    // ── Scrollable body ───────────────────────────────────────────────────────

    Flickable {
        id: _flickable
        anchors {
            left: parent.left; right: parent.right
            top: _topFixed.bottom; bottom: _sysDivider.top
            topMargin: Style.panelCardVpadding
        }
        clip:          true
        contentHeight: _flickCol.implicitHeight

        ColumnLayout {
            id: _flickCol
            width:   parent.width
            spacing: 0

            // ── Notifications tab ─────────────────────────────────────────────

            PanelCard {
                Layout.fillWidth: true
                visible: root._tab === 0

                // Empty state
                Text {
                    Layout.fillWidth:    true
                    Layout.topMargin:    Style.panelElementVpadding
                    Layout.bottomMargin: Style.panelElementVpadding
                    horizontalAlignment: Text.AlignHCenter
                    visible:         !root._hasNotifs
                    text:            "No notifications"
                    color:           Style.textMuted
                    font.family:     Style.fontMono
                    font.pixelSize:  Style.fontSizeBody
                }

                Repeater {
                        model: root.notificationServer ? root.notificationServer.notifications : null

                        delegate: ColumnLayout {
                            id: _entry
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 0

                            // ── Actions filtering ─────────────────────────────

                            readonly property var _filteredActions: {
                                if (!_entry.modelData || !_entry.modelData.actions) return []
                                var acts = _entry.modelData.actions, def = null, others = []
                                for (var i = 0; i < acts.length; i++) {
                                    if (acts[i].identifier === "default") def = acts[i]
                                    else others.push(acts[i])
                                }
                                var res = def ? [def] : []
                                for (var j = 0; j < Math.min(3, others.length); j++) res.push(others[j])
                                return res
                            }
                            readonly property bool _hasActions: _filteredActions.length > 0

                            function _invokeDefault() {
                                var notif = _entry.modelData
                                if (!notif || !notif.actions) return
                                for (var i = 0; i < notif.actions.length; i++) {
                                    if (notif.actions[i].identifier === "default") {
                                        notif.actions[i].invoke(); break
                                    }
                                }
                                if (!notif.resident) notif.dismiss()
                            }

                            // Divider between entries
                            PanelDivider {
                                visible: _entry.index > 0
                                Layout.fillWidth: true
                                Layout.topMargin:    Style.panelElementVpadding
                                Layout.bottomMargin: Style.panelElementVpadding
                            }

                            // ── Row 1: main content ───────────────────────────

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.panelCardHpadding

                                TapHandler { acceptedButtons: Qt.RightButton; onTapped: _entry.modelData.dismiss() }

                                // Col1: App icon
                                AppIcon {
                                    iconName: _entry.modelData.appIcon || ""
                                    category: _entry.modelData.hints
                                        ? (_entry.modelData.hints["category"] || "") : ""
                                    Layout.preferredWidth:  Style.buttonHeight + 8
                                    Layout.preferredHeight: Style.buttonHeight + 8
                                    Layout.alignment: Qt.AlignTop
                                    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: _entry._invokeDefault() }
                                }

                                // Col2: Summary + body + meta
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignTop
                                    spacing: Style.panelElementHpadding

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Style.panelElementHpadding

                                        Text {
                                            text:             _entry.modelData.appName || ""
                                            color:            Style.textMuted
                                            font.family:      Style.fontMono
                                            font.pixelSize:   Style.fontSizeSubtle
                                            elide:            Text.ElideRight
                                            Layout.fillWidth: true
                                            visible:          text !== ""
                                        }

                                        Text {
                                            property var _ts: root.notificationServer
                                                ? root.notificationServer.getTimestamp(_entry.modelData.id)
                                                : null
                                            text:           _ts ? Qt.formatTime(_ts, "hh:mm") : ""
                                            color:          Style.textMuted
                                            font.family:    Style.fontMono
                                            font.pixelSize: Style.fontSizeSubtle
                                            visible:        text !== ""
                                        }
                                    }

                                    Text {
                                        id: _summaryText
                                        Layout.fillWidth: true
                                        text:             _entry.modelData.summary || ""
                                        color:            Style.textNormal
                                        font.family:      Style.fontMono
                                        font.pixelSize:   Style.fontSizeHeading
                                        wrapMode:         Text.WordWrap
                                        maximumLineCount: Prefs.bankMaxLines
                                        elide:            Text.ElideRight
                                        visible:          text !== ""

                                        HoverHandler { id: _summaryHover }
                                        QQC.ToolTip.visible: truncated && _summaryHover.hovered
                                        QQC.ToolTip.text:    _entry.modelData.summary || ""
                                        QQC.ToolTip.delay:   500
                                    }

                                    Loader {
                                        Layout.fillWidth: true
                                        visible: (_entry.modelData.body || "") !== ""
                                        active:  visible
                                        sourceComponent: (_entry.modelData.body || "").includes("<")
                                            ? _richBodyComp : _plainBodyComp
                                    }

                                    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: _entry._invokeDefault() }
                                }

                                // Col3: Thumbnail
                                Item {
                                    readonly property int _sz: Style.buttonHeight * 2
                                    Layout.preferredWidth:  (_entry.modelData.image !== "") ? _sz : 0
                                    Layout.preferredHeight: _sz
                                    Layout.alignment: Qt.AlignTop
                                    clip: true
                                    Behavior on Layout.preferredWidth {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    Image {
                                        anchors.fill: parent
                                        source:       _entry.modelData.image || ""
                                        fillMode:     Image.PreserveAspectCrop
                                    }

                                    TapHandler {
                                        acceptedButtons: Qt.LeftButton
                                        enabled: _entry.modelData.image !== ""
                                        onTapped: _entry._invokeDefault()
                                    }
                                }

                                // Col4: Dismiss
                                ColumnLayout {
                                    Layout.alignment: Qt.AlignTop
                                    spacing: 0
                                    IconButton { label: "×"; onClicked: _entry.modelData.dismiss() }
                                }
                            }

                            // Divider + action row
                            PanelDivider { visible: _entry._hasActions; Layout.fillWidth: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Style.panelElementHpadding
                                visible: _entry._hasActions

                                Repeater {
                                    model: _entry._filteredActions
                                    delegate: PanelButton {
                                        required property var modelData
                                        label:            modelData.text
                                        Layout.fillWidth: true
                                        onClicked: {
                                            modelData.invoke()
                                            _entry.modelData.dismiss()
                                        }
                                    }
                                }
                            }

                            // Body text components — defined in delegate scope to access modelData
                            Component {
                                id: _richBodyComp
                                Text {
                                    text:             _entry.modelData.body || ""
                                    color:            Style.textSecondary
                                    font.family:      Style.fontMono
                                    font.pixelSize:   Style.fontSizeBody
                                    textFormat:       Text.RichText
                                    wrapMode:         Text.WordWrap
                                    maximumLineCount: Prefs.bankMaxLines
                                    elide:            Text.ElideRight
                                    onLinkActivated:  (link) => Qt.openUrlExternally(link)
                                }
                            }

                            Component {
                                id: _plainBodyComp
                                Text {
                                    text:             _entry.modelData.body || ""
                                    color:            Style.textSecondary
                                    font.family:      Style.fontMono
                                    font.pixelSize:   Style.fontSizeBody
                                    wrapMode:         Text.WordWrap
                                    maximumLineCount: Prefs.bankMaxLines
                                    elide:            Text.ElideRight

                                    HoverHandler { id: _bodyHover }
                                    QQC.ToolTip.visible: truncated && _bodyHover.hovered
                                    QQC.ToolTip.text:    _entry.modelData.body || ""
                                    QQC.ToolTip.delay:   500
                                }
                            }
                        }
                    }
            }

            // ── Screenshots tab ───────────────────────────────────────────────

            PanelCard {
                Layout.fillWidth: true
                visible: root._tab === 1

                Text {
                    Layout.fillWidth:    true
                    Layout.topMargin:    Style.panelElementVpadding
                    Layout.bottomMargin: Style.panelElementVpadding
                    horizontalAlignment: Text.AlignHCenter
                    visible:         root._shots.length === 0
                    text:            "No screenshots"
                    color:           Style.textMuted
                    font.family:     Style.fontMono
                    font.pixelSize:  Style.fontSizeBody
                }

                Repeater {
                        model: root._shots

                        delegate: ColumnLayout {
                            id: _shotEntry
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 0

                            PanelDivider {
                                visible: _shotEntry.index > 0
                                Layout.fillWidth: true
                                Layout.topMargin:    Style.panelElementVpadding
                                Layout.bottomMargin: Style.panelElementVpadding
                            }

                            // Item + anchors avoids RowLayout's circular parent.width issue
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: _thumb.height

                                readonly property int _gap: Style.panelCardHpadding

                                MediaThumbnail {
                                    id: _thumb
                                    source: root.screenshotProcess && root.screenshotProcess.thumbsReady[_shotEntry.modelData.path]
                                        ? root.screenshotProcess.thumbPath(_shotEntry.modelData.path)
                                        : _shotEntry.modelData.path
                                    filename:  ""
                                    fillMode:  Image.PreserveAspectCrop
                                    anchors.left: parent.left
                                    anchors.top:  parent.top
                                    width:  (parent.width - parent._gap) / 2
                                    height: Math.round(width * 9 / 16)
                                    onThumbnailClicked: _xdgOpen.running = true

                                    HoverHandler {
                                        onHoveredChanged: root.hoveredShotPath =
                                            hovered ? _shotEntry.modelData.path : ""
                                    }

                                    Process {
                                        id: _xdgOpen
                                        command: ["xdg-open", _shotEntry.modelData.path]
                                    }
                                }

                                ColumnLayout {
                                    id: _meta
                                    anchors {
                                        left:       _thumb.right
                                        leftMargin: parent._gap
                                        right:      parent.right
                                        top:        parent.top
                                    }
                                    spacing: Style.panelElementHpadding

                                    Text {
                                        text:             _shotEntry.modelData.name
                                        color:            Style.textNormal
                                        font.family:      Style.fontMono
                                        font.pixelSize:   Style.fontSizeSubtle
                                        elide:            Text.ElideMiddle
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text:           Qt.formatTime(new Date(_shotEntry.modelData.timestamp), "hh:mm:ss")
                                        color:          Style.textMuted
                                        font.family:    Style.fontMono
                                        font.pixelSize: Style.fontSizeSubtle
                                    }

                                    RowLayout {
                                        spacing: Style.panelElementHpadding

                                        PanelButton {
                                            label: "Open"
                                            onClicked: _xdgOpen.running = true
                                        }

                                        PanelButton {
                                            label:    "Copy"
                                            onClicked: _copyImg.running = true

                                            Process {
                                                id: _copyImg
                                                command: ["pillbox-copy-multi", _shotEntry.modelData.path]
                                            }
                                        }

                                        PanelButton {
                                            label:    "Delete"
                                            variant:  "critical"
                                            onClicked: root.screenshotProcess
                                                && root.screenshotProcess.deleteScreenshot(_shotEntry.modelData.path)
                                        }
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }

    // ── SysTray footer ────────────────────────────────────────────────────────

    Rectangle {
        id: _sysDivider
        anchors {
            bottom:       _trayBar.top
            left:         parent.left
            right:        parent.right
            bottomMargin: _trayBar.count > 0 ? Style.panelElementVpadding : 0
        }
        height: _trayBar.count > 0 ? 1 : 0
        color:  Style.panelBorderColor
    }

    SysTrayBar {
        id: _trayBar
        anchors {
            bottom:       parent.bottom
            bottomMargin: _trayBar.count > 0 ? Style.panelMargin : 0
            right:        parent.right
        }
        height: _trayBar.count > 0 ? 24 : 0
    }
}
