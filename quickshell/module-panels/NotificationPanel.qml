import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell.Services.Notifications

Item {
    id: root

    property var notificationServer: null
    signal navigateRequested(int direction)

    readonly property bool _hasNotifs: notificationServer && notificationServer.countTotal > 0

    // Natural height = fixed top + cards (unconstrained) + systray footer + padding.
    // PanelSurface clamps this to _maxHeight; the Flickable fills whatever remains.
    implicitHeight: _topFixed.implicitHeight
                  + (_hasNotifs ? _cardCol.implicitHeight + 8 + Style.panelMargin
                                : 40)
                  + (_trayBar.count > 0 ? (1 + 24 + Style.panelMargin) : 0)
                  + Style.panelMargin * 2 + 24

    // ── Background ────────────────────────────────────────────────────────────

    Rectangle {
        anchors.fill:  parent
        radius:        Style.radLg
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
            onNavigateRequested: (dir) => root.navigateRequested(dir)
        }

        PanelButton {
            Layout.alignment: Qt.AlignRight
            visible:          root._hasNotifs
            variant:          "critical"
            label:            "Clear all"
            onClicked:        root.notificationServer && root.notificationServer.clearAll()
        }
    }

    // ── Empty state ───────────────────────────────────────────────────────────

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              _topFixed.bottom
        anchors.topMargin:        16
        visible:                  !root._hasNotifs
        text:                     "No notifications"
        color:                    Style.textMuted
        font.family:              Style.fontMono
        font.pixelSize:           Style.fontSizeBody
    }

    // ── Scrollable card list ──────────────────────────────────────────────────

    Flickable {
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
        visible:       root._hasNotifs
        contentHeight: _cardCol.implicitHeight
        clip:          true

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

                    radius:       Style.radMd
                    border.width: Style.elementBorderWidth
                    border.color: Style.borderFaintColor

                    color: {
                        var u = _card.modelData.urgency
                        if (u === NotificationUrgency.Critical)
                            return Qt.rgba(Style.color11.r, Style.color11.g, Style.color11.b, 0.15)
                        if (u === NotificationUrgency.Low)
                            return Style.surfaceLowColor
                        return Style.surfaceMidColor
                    }

                    // Per-card expand state for overflow actions
                    property bool _expanded: false

                    // Filtered labeled actions (exclude "default" identifier)
                    readonly property var _labeledActions: {
                        var acts = _card.modelData.actions
                        if (!acts) return []
                        var result = []
                        for (var i = 0; i < acts.length; i++) {
                            if (acts[i].identifier !== "default") result.push(acts[i])
                        }
                        return result
                    }

                    // Right click anywhere on card → dismiss
                    // Left-click-to-invoke-default is deferred: in Qt 6, card-level TapHandler
                    // fires even when child buttons are clicked, causing accidental dismissal.
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: _card.modelData.dismiss()
                    }

                    RowLayout {
                        id:      _cardRow
                        anchors {
                            top:    parent.top
                            left:   parent.left
                            right:  parent.right
                            margins: 8
                        }
                        spacing: 8

                        // ── Left: image thumbnail ─────────────────────────────

                        Rectangle {
                            visible:                _card.modelData.image !== ""
                            Layout.preferredWidth:  56
                            Layout.preferredHeight: 56
                            Layout.alignment:       Qt.AlignTop
                            radius:                 Style.radSm
                            color:                  Style.surfaceLowColor
                            clip:                   true

                            Image {
                                anchors.fill: parent
                                source:       _card.modelData.image || ""
                                fillMode:     Image.PreserveAspectCrop
                                visible:      status === Image.Ready
                            }
                        }

                        // ── Right: content ────────────────────────────────────

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            // Header: spacer + timestamp + [×]
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                // App name
                                Text {
                                    text:           _card.modelData.appName || ""
                                    color:          Style.textMuted
                                    font.family:    Style.fontMono
                                    font.pixelSize: Style.fontSizeSubtle
                                    elide:          Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }

                                // Timestamp
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

                                // [×] dismiss button
                                Rectangle {
                                    width:  Style.buttonHeight - 4
                                    height: Style.buttonHeight - 4
                                    radius: Style.radSm
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

                            // Summary
                            Text {
                                Layout.fillWidth: true
                                text:           _card.modelData.summary || ""
                                color:          Style.textNormal
                                font.family:    Style.fontMono
                                font.pixelSize: Style.fontSizeBody
                                wrapMode:       Text.WordWrap
                                visible:        text !== ""
                            }

                            // Body
                            Text {
                                Layout.fillWidth: true
                                text:           _card.modelData.body || ""
                                color:          Style.textSecondary
                                font.family:    Style.fontMono
                                font.pixelSize: Style.fontSizeSubtle
                                wrapMode:       Text.WordWrap
                                visible:        text !== ""
                            }

                            // Primary action row: up to 2 buttons + ⋮ if more
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

                                // ⋮ more button
                                IconButton {
                                    visible:   _card._labeledActions.length > 2
                                    label:     "⋮"
                                    fontFamily: Style.fontMono
                                    onClicked: _card._expanded = !_card._expanded
                                }
                            }

                            // Overflow action row: actions 2 and 3
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

    // ── Systray footer ────────────────────────────────────────────────────────
    // _sysDivider anchors above _trayBar; Flickable anchors its bottom here.
    // When no tray items both heights collapse to 0 so Flickable fills parent.

    Rectangle {
        id: _sysDivider
        anchors {
            bottom: _trayBar.top
            left:   parent.left
            right:  parent.right
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
            rightMargin:  Style.panelMargin
        }
        height: _trayBar.count > 0 ? 24 : 0
    }
}
