import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property var    model:        []
    property int    currentIndex: 0
    property string emptyText:    ""

    signal activated(int index)

    spacing: 4
    implicitHeight: _heroH

    property int _direction: 1

    // ── Sizing ────────────────────────────────────────────────────────────────
    readonly property real _nearW: width * 0.20
    readonly property real _smallW: _nearW / 2
    readonly property real _nearH: _nearW * 16.0 / 9.0
    readonly property real _heroH: _nearH * 1.02

    // ── Visible window ────────────────────────────────────────────────────────
    // Returns {hero, near, smalls[]} — which indices are visible and their roles.
    // Behind items fill SMALL slots nearest-first; further upcoming fills remainder.
    readonly property var _window: {
        const count = root.model ? root.model.length : 0
        const w = { hero: root.currentIndex, near: -1, smalls: [] }
        if (count === 0) return w

        const nearIdx = root.currentIndex + root._direction
        if (nearIdx >= 0 && nearIdx < count) w.near = nearIdx

        let filled = 0
        for (let d = 1; filled < 2; d++) {
            const behindIdx = root.currentIndex - root._direction * d
            if (behindIdx < 0 || behindIdx >= count) break
            w.smalls.push(behindIdx)
            filled++
        }
        for (let d = 2; filled < 2; d++) {
            const aheadIdx = root.currentIndex + root._direction * d
            if (aheadIdx < 0 || aheadIdx >= count) break
            w.smalls.push(aheadIdx)
            filled++
        }
        return w
    }

    // HERO width: fills whatever NEAR and SMALL leave behind.
    // Computed explicitly so all tiers animate via Behavior on preferredWidth.
    readonly property real _heroW: {
        const n = (_window.near >= 0) ? 1 : 0
        const s = _window.smalls.length
        return Math.max(0, width - n * _nearW - s * _smallW - spacing * (n + s))
    }

    // ── Empty state ───────────────────────────────────────────────────────────
    Text {
        visible:               !root.model || root.model.length === 0
        text:                  root.emptyText
        Layout.fillWidth:      true
        Layout.preferredHeight: root._heroH
        horizontalAlignment:   Text.AlignHCenter
        verticalAlignment:     Text.AlignVCenter
        color:                 Style.textMuted
        font.family:           Style.fontMono
        font.pixelSize:        Style.fontSizeBody
        wrapMode:              Text.Wrap
    }

    // ── Slides ────────────────────────────────────────────────────────────────
    Repeater {
        model: root.model

        delegate: Rectangle {
            id: slot
            required property var modelData
            required property int index

            readonly property bool _isHero:  index === root._window.hero
            readonly property bool _isNear:  index === root._window.near
            readonly property bool _isSmall: root._window.smalls.indexOf(index) !== -1

            visible: _isHero || _isNear || _isSmall
            clip:    true
            color:   "transparent"

            Layout.alignment:       Qt.AlignVCenter
            Layout.preferredWidth:  _isHero ? root._heroW : _isNear ? root._nearW : root._smallW
            Layout.preferredHeight: _isHero ? root._heroH : root._nearH

            Behavior on Layout.preferredWidth  { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // Image spans the full row width; each slot clips its positional strip.
            // x = -slot.x offsets left edge to row origin; y centers vertically.
            Image {
                source:       "file://" + slot.modelData.path
                width:        root.width
                height:       implicitWidth > 0 ? width * (implicitHeight / implicitWidth) : root._heroH
                x:            -slot.x
                y:            -(height - slot.height) / 2
                fillMode:     Image.Pad
                asynchronous: true
                smooth:       true
            }

            // Active border on HERO
            Rectangle {
                anchors.fill:  parent
                color:         "transparent"
                border.width:  slot._isHero ? 2 : 0
                border.color:  Style.accentColor
            }

            TapHandler {
                onTapped: {
                    root._direction   = index > root.currentIndex ? 1 : (index < root.currentIndex ? -1 : root._direction)
                    root.currentIndex = index
                    root.activated(index)
                }
            }
        }
    }

    // ── Wheel ─────────────────────────────────────────────────────────────────
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            event.accepted = true
            const count = root.model ? root.model.length : 0
            if (count === 0) return
            const dir  = event.angleDelta.y < 0 ? 1 : -1
            const next = Math.max(0, Math.min(count - 1, root.currentIndex + dir))
            if (next === root.currentIndex) return
            root._direction   = dir
            root.currentIndex = next
            root.activated(next)
        }
    }
}
