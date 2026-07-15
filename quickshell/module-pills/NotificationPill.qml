import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Item {
    id: root

    property var notificationServer: null

    // ── Priority interface (read by PillController) ───────────────────────────

    readonly property bool _hasCritical: notificationServer ? notificationServer.countCritical > 0 : false
    readonly property bool _hasAny:      notificationServer ? notificationServer.countTotal > 0 : false

    property bool _peeking:         false
    property bool _peekingCritical: false

    readonly property int priority: {
        if (_peekingCritical && _hasAny) return 1000
        if (_peeking && _hasAny)         return 6
        return 0
    }
    readonly property bool shouldReveal: (_peeking || _peekingCritical) && _hasAny

    // ── Display notification — most recently arrived ──────────────────────────

    readonly property var _displayNotif: {
        if (!notificationServer || !notificationServer.notifications) return null
        var vals = notificationServer.notifications.values
        return vals.length > 0 ? vals[vals.length - 1] : null
    }

    readonly property bool _hasActions: {
        if (!_displayNotif || !_displayNotif.actions) return false
        var acts = _displayNotif.actions
        for (var i = 0; i < acts.length; i++) {
            if (acts[i].identifier !== "default") return true
        }
        return false
    }

    // ── Peek triggers ─────────────────────────────────────────────────────────

    Connections {
        target: notificationServer
        enabled: notificationServer !== null
        function onNewNotification(notif) {
            if (notif && notif.urgency === NotificationUrgency.Critical) {
                root._peekingCritical = true
                _criticalPeekTimer.restart()
            }
            root._peeking = true
            _peekTimer.restart()
        }
    }

    Timer { id: _peekTimer;         interval: 7000;  onTriggered: root._peeking = false }
    Timer { id: _criticalPeekTimer; interval: 10000; onTriggered: root._peekingCritical = false }

    // ── Visual component ──────────────────────────────────────────────────────

    readonly property color bgColor: _hasCritical ? Style.criticalBgColor : Style.pillBgColor

    property Component visualComponent: Component {
        RowLayout {
            id: _row
            spacing: 6

            // One-shot scale thump on critical arrival
            property bool criticalActive: root._peekingCritical
            onCriticalActiveChanged: if (criticalActive) _thump.restart()

            SequentialAnimation {
                id: _thump
                NumberAnimation { target: _row; property: "scale"; to: 1.04; duration: 150; easing.type: Easing.OutCubic }
                NumberAnimation { target: _row; property: "scale"; to: 1.0;  duration: 150; easing.type: Easing.InCubic }
            }

            // ── Col 1: Thumbnail ──────────────────────────────────────────────
            // Visible only when the notification image loads successfully.
            // App icon fallback (image://theme/appIcon) deferred — needs API check.
            // Size derived from Prefs directly (not parent.height) to avoid circularity
            // with the content-driven PillWindow implicitHeight.

            Rectangle {
                visible:                _thumbImg.status === Image.Ready
                Layout.preferredWidth:  Style.fontSizePill + Style.pillPaddingV - 8
                Layout.preferredHeight: Style.fontSizePill + Style.pillPaddingV - 8
                Layout.alignment:       Qt.AlignVCenter
                radius: 3
                color:  Style.surfaceLowColor
                clip:   true

                Image {
                    id: _thumbImg
                    anchors.fill: parent
                    source:       root._displayNotif ? (root._displayNotif.image || "") : ""
                    fillMode:     Image.PreserveAspectCrop
                }
            }

            // ── Col 2: Text column ────────────────────────────────────────────

            ColumnLayout {
                Layout.preferredWidth: Math.round(Screen.width * 0.10)
                Layout.alignment:      Qt.AlignVCenter
                spacing: 2

                // Row 1 — App name: persistent context, visually subordinate
                Text {
                    Layout.fillWidth: true
                    visible:        text !== ""
                    text:           root._displayNotif ? (root._displayNotif.appName || "") : ""
                    color:          Style.textMuted
                    font.family:    Style.fontMono
                    font.pixelSize: Style.fontSizeBase - 2
                    elide:          Text.ElideRight
                }

                // Row 2 — Summary + body: the actual message, gets visual priority
                ScrollingText {
                    Layout.fillWidth: true
                    text: {
                        if (!root._displayNotif) return ""
                        var s = root._displayNotif.summary || ""
                        var b = root._displayNotif.body    || ""
                        return b ? s + " — " + b : s
                    }
                    color:          root._hasCritical ? Style.textCritical : Style.textPrimary
                    font.family:    Style.fontMono
                    font.pixelSize: Style.fontSizePill
                }
            }

            // ── Col 3: Actionable dot ─────────────────────────────────────────
            // Passive signal: "actions are available in the notification panel (W-6)".
            // Not interactive. Blinks faster on critical urgency.

            Text {
                id: _dot
                visible:          root._hasActions
                Layout.alignment: Qt.AlignVCenter
                text:             String.fromCodePoint(0xf444)
                color:            root._hasCritical ? Style.mat3OnErrorContainer : Style.accentColor
                font.family:      Style.fontNerd
                font.pixelSize:   Style.fontSizeSubtle

                SequentialAnimation {
                    loops:   Animation.Infinite
                    running: _dot.visible && !root._hasCritical
                    onRunningChanged: if (running) _dot.opacity = 1.0
                    NumberAnimation { target: _dot; property: "opacity"; to: 0.15; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { target: _dot; property: "opacity"; to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
                }

                SequentialAnimation {
                    loops:   Animation.Infinite
                    running: _dot.visible && root._hasCritical
                    onRunningChanged: if (running) _dot.opacity = 1.0
                    NumberAnimation { target: _dot; property: "opacity"; to: 0.15; duration: 250; easing.type: Easing.InOutSine }
                    NumberAnimation { target: _dot; property: "opacity"; to: 1.0;  duration: 250; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ── Logging ───────────────────────────────────────────────────────────────

    onPriorityChanged:     console.log("[NotificationPill] priority:", priority,
        "| total:", notificationServer ? notificationServer.countTotal : 0,
        "| critical:", notificationServer ? notificationServer.countCritical : 0)
    onShouldRevealChanged: console.log("[NotificationPill] shouldReveal:", shouldReveal)
    Component.onCompleted: console.log("[NotificationPill] started")
}
