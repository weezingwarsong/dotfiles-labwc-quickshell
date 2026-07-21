import QtQuick

Item {
    id: root

    property var bars: []

    property real rotationAngle: 0.0

    readonly property real maxIntensity: {
        if (!bars || bars.length === 0) return 0.0
        var m = 0.0
        for (var i = 0; i < bars.length; i++)
            if (bars[i] > m) m = bars[i]
        return m
    }

    function getBucket(i) {
        if (!bars || bars.length === 0) return 0.0
        var group = Math.max(1, Math.floor(bars.length / 16))
        var val = 0.0
        for (var j = 0; j < group; j++) {
            var idx = i * group + j
            if (idx < bars.length) val = Math.max(val, bars[idx])
        }
        return val
    }

    FrameAnimation {
        running: root.visible
        onTriggered: {
            root.rotationAngle = (root.rotationAngle + root.maxIntensity * 2.5 * frameTime) % 6.2831853
        }
    }

    ShaderEffect {
        anchors.fill: parent

        property color    accentColor:   Style.accentColor
        property real     rotationAngle: root.rotationAngle
        property vector4d bars0: Qt.vector4d(getBucket(0),  getBucket(1),  getBucket(2),  getBucket(3))
        property vector4d bars1: Qt.vector4d(getBucket(4),  getBucket(5),  getBucket(6),  getBucket(7))
        property vector4d bars2: Qt.vector4d(getBucket(8),  getBucket(9),  getBucket(10), getBucket(11))
        property vector4d bars3: Qt.vector4d(getBucket(12), getBucket(13), getBucket(14), getBucket(15))

        fragmentShader: Qt.resolvedUrl("RadialVisualizer.frag.qsb")
    }
}
