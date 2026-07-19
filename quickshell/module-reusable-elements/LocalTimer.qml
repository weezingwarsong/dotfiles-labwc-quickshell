import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string timerId:            ""
    property int    duration:           0       // milliseconds
    property int    variant:            1       // 1 = process only; 2-5 = bar visuals
    property color  color:              Style.accentColor
    property var    localTimerProcess:  null

    signal completed()

    // Stops and removes the timer immediately. No completed signal is emitted.
    function kill() {
        if (root.localTimerProcess && root.timerId !== "")
            root.localTimerProcess.kill(root.timerId)
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    Component.onCompleted: {
        if (!root.localTimerProcess) {
            console.error("[LocalTimer] localTimerProcess is null for id '" + root.timerId + "'")
            return
        }
        if (root.timerId === "") {
            console.error("[LocalTimer] timerId is empty — timer will not be registered")
            return
        }
        root.localTimerProcess.register(root.timerId, root.duration)
    }

    Connections {
        target: root.localTimerProcess
        function onTimerCompleted(id) {
            if (id !== root.timerId) return
            console.log("[LocalTimer] completed:", root.timerId)
            root.completed()
        }
    }

    // ── Fill ratio ───────────────────────────────────────────────────────────

    // Recomputed every 50ms when a bar variant is active.
    property real _fillRatio: 0.0

    Timer {
        id: displayTick
        interval: 50
        repeat:   true
        running:  root.variant >= 2 && root.localTimerProcess !== null && root.localTimerProcess.status(root.timerId) === "started"
        onTriggered: {
            var rem = root.localTimerProcess.remaining(root.timerId)
            var el  = root.localTimerProcess.elapsed(root.timerId)
            var total = el + rem
            root._fillRatio = total > 0 ? Math.min(1.0, el / total) : 1.0
        }
    }

    // ── Visuals ──────────────────────────────────────────────────────────────

    // Variant 1: no visual. The Item itself is 0x0.
    implicitWidth:  _bar.implicitWidth
    implicitHeight: _bar.implicitHeight

    Loader {
        id: _bar
        anchors.fill: parent
        active: root.variant >= 2

        sourceComponent: {
            switch (root.variant) {
                case 2: return _hBar
                case 3: return _vBar
                case 4: return _hBarRemain
                case 5: return _vBarRemain
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
                height: 2
                color:  root.color
                width:  parent.width * root._fillRatio
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
                width:  2
                color:  root.color
                height: parent.height * root._fillRatio
                anchors.bottom: parent.bottom
                Behavior on height { SmoothedAnimation { velocity: -1; duration: 100 } }
            }
        }
    }

    // Variant 4 — horizontal remaining (shrinks right)
    Component {
        id: _hBarRemain
        Item {
            implicitHeight: 2
            Layout.fillWidth: true
            Rectangle {
                height: 2
                color:  root.color
                width:  parent.width * (1.0 - root._fillRatio)
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
                width:  2
                color:  root.color
                height: parent.height * (1.0 - root._fillRatio)
                anchors.top: parent.top
                Behavior on height { SmoothedAnimation { velocity: -1; duration: 100 } }
            }
        }
    }
}
