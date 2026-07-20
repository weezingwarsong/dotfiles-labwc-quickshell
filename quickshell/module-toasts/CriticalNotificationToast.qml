import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Item {
    id: root

    property var notificationServer: null

    readonly property bool shouldShow: _notif !== null
    property var  _notif: null

    implicitHeight: _notif !== null ? _card.implicitHeight : 0
    visible:        _notif !== null

    // ── Notification arrival ──────────────────────────────────────────────────

    Connections {
        target: root.notificationServer
        function onNewNotification(notif) {
            if (notif.urgency !== NotificationUrgency.Critical) return
            _toastTimer.kill()
            root._notif = notif
            root._startTimer()
        }
    }

    // ── Timer lifecycle ───────────────────────────────────────────────────────

    function _startTimer() {
        var notif = root._notif
        if (!notif) return
        // Critical with no app-provided timeout: spec says must not auto-dismiss
        if (notif.expireTimeout <= 0) return
        _toastTimer.start(Math.round(notif.expireTimeout))
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    readonly property var _filteredActions: {
        if (!root._notif || !root._notif.actions) return []
        var acts = root._notif.actions, def = null, others = []
        for (var i = 0; i < acts.length; i++) {
            if (acts[i].identifier === "default") def = acts[i]
            else others.push(acts[i])
        }
        var res = def ? [def] : []
        for (var j = 0; j < Math.min(3, others.length); j++) res.push(others[j])
        return res
    }
    readonly property bool _hasActions: _filteredActions.length > 0

    // ── Dismiss / invoke ──────────────────────────────────────────────────────

    function _dismiss() {
        if (root._notif === null) return
        _toastTimer.kill()
        root._notif = null
    }

    function _skipAndDismiss() {
        if (root._notif === null) return
        var n = root._notif
        root._dismiss()
        n.dismiss()
    }

    function _invokeDefault() {
        var notif = root._notif
        if (!notif) return
        if (notif.actions) for (var i = 0; i < notif.actions.length; i++) {
            if (notif.actions[i].identifier === "default") { notif.actions[i].invoke(); break }
        }
        if (notif.resident) {
            _toastTimer.kill()
        } else {
            root._dismiss()
        }
    }

    // ── Computed ──────────────────────────────────────────────────────────────

    readonly property bool _bodyIsRich: root._notif !== null
        && root._notif.body !== ""
        && root._notif.body.includes("<")

    readonly property int _thumbSize: Style.buttonHeight * 2

    // ── Hover — pause / resume timer ─────────────────────────────────────────

    HoverHandler {
        onHoveredChanged: {
            if (!_toastTimer.running) return
            if (hovered) _toastTimer.pause()
            else         _toastTimer.resume()
        }
    }

    // ── Card ──────────────────────────────────────────────────────────────────

    PanelCard {
        id: _card
        anchors.fill: parent
        color: Style.criticalBgColor

        ColumnLayout {
            spacing: 8
            Layout.fillWidth: true

            // ── Row1 — main content ───────────────────────────────────────────

            RowLayout {
                id: _row1
                spacing: 8
                Layout.fillWidth: true

                TapHandler { acceptedButtons: Qt.RightButton; onTapped: root._dismiss() }

                // Col1 — App icon
                AppIcon {
                    iconName: root._notif ? root._notif.appIcon : ""
                    category: root._notif && root._notif.hints
                        ? (root._notif.hints["category"] || "") : ""
                    Layout.preferredWidth:  Style.buttonHeight + 8
                    Layout.preferredHeight: Style.buttonHeight + 8
                    Layout.alignment: Qt.AlignTop
                    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: root._invokeDefault() }
                }

                // Col2 — Summary + body
                ColumnLayout {
                    spacing: 4
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop

                    ScrollingText {
                        text:  root._notif ? root._notif.summary : ""
                        color: Style.textNormal
                        Layout.fillWidth: true
                        font.pixelSize:   Style.fontSizeHeading
                    }

                    Loader {
                        Layout.fillWidth: true
                        visible: root._notif !== null && root._notif.body !== ""
                        active:  visible
                        sourceComponent: root._bodyIsRich ? _richBodyComp : _plainBodyComp
                    }

                    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: root._invokeDefault() }
                }

                // Col3 — Thumbnail
                Item {
                    Layout.preferredWidth:  (root._notif && root._notif.image !== "") ? root._thumbSize : 0
                    Layout.preferredHeight: root._thumbSize
                    Layout.alignment: Qt.AlignTop
                    clip: true
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Image {
                        anchors.fill: parent
                        source:   (root._notif && root._notif.image !== "") ? root._notif.image : ""
                        fillMode: Image.PreserveAspectCrop
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        enabled: root._notif !== null && root._notif.image !== ""
                        onTapped: root._invokeDefault()
                    }
                }

                // Col4 — Service actions
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: 0
                    IconButton { label: "×"; onClicked: root._skipAndDismiss() }
                }
            }

            // ── Divider ───────────────────────────────────────────────────────

            PanelDivider { visible: root._hasActions }

            // ── Caller action row ─────────────────────────────────────────────

            RowLayout {
                spacing: 4
                Layout.fillWidth: true
                visible: root._hasActions

                Repeater {
                    model: root._filteredActions
                    delegate: PanelButton {
                        required property var modelData
                        label:            modelData.text
                        Layout.fillWidth: true
                        onClicked: {
                            modelData.invoke()
                            if (root._notif && root._notif.resident) {
                                _toastTimer.kill()
                            } else {
                                root._dismiss()
                            }
                        }
                    }
                }
            }

            // ── Timer bar (only active when app specifies expireTimeout > 0) ──

            LocalTimer {
                id: _toastTimer
                variant: 4
                color:   Style.accentColor
                Layout.fillWidth: true
                visible: running
                onCompleted: root._dismiss()
            }
        }
    }

    // ── Body text components ──────────────────────────────────────────────────

    Component {
        id: _richBodyComp
        Text {
            text:             root._notif ? root._notif.body : ""
            color:            Style.textCritical
            font.family:      Style.fontMono
            font.pixelSize:   Style.fontSizeBody
            textFormat:       Text.RichText
            wrapMode:         Text.WordWrap
            maximumLineCount: 8
            elide:            Text.ElideRight
            onLinkActivated:  (link) => Qt.openUrlExternally(link)
        }
    }

    Component {
        id: _plainBodyComp
        ScrollingText {
            text:           root._notif ? root._notif.body : ""
            color:          Style.textCritical
            font.pixelSize: Style.fontSizeBody
        }
    }
}
