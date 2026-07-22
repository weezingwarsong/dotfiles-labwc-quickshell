import QtQuick

Item {
    id: root

    property real   value:         0.0
    property string label:         ""
    property color  successColor:  Style.textSuccess
    property color  criticalColor: Style.textCritical

    implicitHeight: width

    // Continuous time for shader animation: 1 unit = 1 second
    // Loops at 9990 s (333 × 30 s laps) — dot angle is seamless at loop point
    property real _time: 0.0
    NumberAnimation on _time {
        from:     0.0
        to:       9990.0
        duration: 9990000
        loops:    Animation.Infinite
        running:  true
    }

    // ── Shader ────────────────────────────────────────────────────────────────

    ShaderEffect {
        anchors.fill:   parent
        fragmentShader: Qt.resolvedUrl("orbit.frag.qsb")

        property real  value:         root.value
        property real  time:          root._time
        property color successColor:  root.successColor
        property color criticalColor: root.criticalColor
    }

    // ── Text overlay ──────────────────────────────────────────────────────────

    // Default: live integer value (0–100, no % sign)
    Text {
        anchors.centerIn: parent
        text:           Math.round(root.value * 100).toString()
        color:          Style.textNormal
        font.family:    Style.fontMono
        font.pixelSize: root.height * 0.3
        opacity:        _hover.hovered ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // Hover: metric label
    Text {
        anchors.centerIn: parent
        text:           root.label
        color:          Style.textNormal
        font.family:    Style.fontMono
        font.pixelSize: root.height * 0.3
        opacity:        _hover.hovered ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    HoverHandler { id: _hover }
}
