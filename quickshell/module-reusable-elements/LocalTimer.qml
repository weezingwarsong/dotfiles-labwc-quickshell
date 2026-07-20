import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int   variant: 1             // 1=no visual; 2=hElapsed; 3=vElapsed; 4=hRemain; 5=vRemain
    property color color:   Style.accentColor

    signal completed()

    // ── Public state ──────────────────────────────────────────────────────────

    readonly property bool running: _state === "running"
    readonly property bool paused:  _state === "paused"

    // ── API ───────────────────────────────────────────────────────────────────

    function start(durationMs) {
        if (durationMs <= 0) return
        _durationMs = durationMs
        _startedAt  = Date.now()
        _state      = "running"
        _fillRatio  = 0.0
        if (!_tick.running) _tick.start()
        console.log("[LocalTimer] started:", durationMs + "ms")
    }

    function kill() {
        if (_state === "idle") return
        _tick.stop()
        _state     = "idle"
        _fillRatio = 0.0
        console.log("[LocalTimer] killed")
    }

    function pause() {
        if (_state !== "running") return
        _pausedRemaining = Math.max(0, _durationMs - (Date.now() - _startedAt))
        _state           = "paused"
        _tick.stop()
        console.log("[LocalTimer] paused, remaining:", _pausedRemaining + "ms")
    }

    function resume() {
        if (_state !== "paused") return
        _startedAt = Date.now() - (_durationMs - _pausedRemaining)
        _state     = "running"
        if (!_tick.running) _tick.start()
        console.log("[LocalTimer] resumed")
    }

    function remaining() {
        if (_state === "idle")   return 0
        if (_state === "paused") return _pausedRemaining
        return Math.max(0, _durationMs - (Date.now() - _startedAt))
    }

    function elapsed() {
        if (_state === "idle")   return 0
        if (_state === "paused") return _durationMs - _pausedRemaining
        return Math.min(_durationMs, Date.now() - _startedAt)
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    property string _state:           "idle"   // "idle" | "running" | "paused"
    property real   _durationMs:      0
    property real   _startedAt:       0
    property real   _pausedRemaining: 0
    property real   _fillRatio:       0.0      // elapsed fraction 0→1

    Timer {
        id: _tick
        interval: 50
        repeat:   true
        onTriggered: {
            var el = Date.now() - root._startedAt
            if (el >= root._durationMs) {
                _tick.stop()
                root._fillRatio = 1.0
                root._state     = "idle"
                console.log("[LocalTimer] completed")
                root.completed()
                return
            }
            if (root.variant >= 2)
                root._fillRatio = el / root._durationMs
        }
    }

    // ── Visuals ───────────────────────────────────────────────────────────────

    implicitWidth:  _bar.implicitWidth
    implicitHeight: _bar.implicitHeight

    Loader {
        id: _bar
        anchors.fill: parent
        active: root.variant >= 2

        sourceComponent: {
            switch (root.variant) {
                case 2:  return _hBar
                case 3:  return _vBar
                case 4:  return _hBarRemain
                case 5:  return _vBarRemain
                default: return null
            }
        }
    }

    // Variant 2 — horizontal elapsed (grows right)
    Component {
        id: _hBar
        Item {
            implicitHeight: 2
            Layout.fillWidth: true
            Rectangle {
                height: 2; color: root.color
                width: parent.width * root._fillRatio
                Behavior on width { SmoothedAnimation { velocity: -1; duration: 100 } }
            }
        }
    }

    // Variant 3 — vertical elapsed (grows up)
    Component {
        id: _vBar
        Item {
            implicitWidth: 2
            Layout.fillHeight: true
            Rectangle {
                width: 2; color: root.color
                height: parent.height * root._fillRatio
                anchors.bottom: parent.bottom
                Behavior on height { SmoothedAnimation { velocity: -1; duration: 100 } }
            }
        }
    }

    // Variant 4 — horizontal remaining (shrinks left)
    Component {
        id: _hBarRemain
        Item {
            implicitHeight: 2
            Layout.fillWidth: true
            Rectangle {
                height: 2; color: root.color
                width: parent.width * (1.0 - root._fillRatio)
                Behavior on width { SmoothedAnimation { velocity: -1; duration: 100 } }
            }
        }
    }

    // Variant 5 — vertical remaining (shrinks down)
    Component {
        id: _vBarRemain
        Item {
            implicitWidth: 2
            Layout.fillHeight: true
            Rectangle {
                width: 2; color: root.color
                height: parent.height * (1.0 - root._fillRatio)
                anchors.top: parent.top
                Behavior on height { SmoothedAnimation { velocity: -1; duration: 100 } }
            }
        }
    }
}
