import QtQuick

Canvas {
    id: canvas

    property var bars: []

    onBarsChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        if (bars.length === 0) return

        var cx = width  / 2
        var cy = height / 2
        var ac = Style.accentColor
        var r  = ac.r, g = ac.g, b = ac.b

        var segments  = 16
        var baseR     = 95
        var amp       = 32
        var slotAngle = (Math.PI * 2) / segments
        var arcSpan   = slotAngle * 0.65   // 65% filled, 35% gap

        // group cava bars into 16 buckets, take the max of each
        var group = Math.max(1, Math.floor(bars.length / segments))

        ctx.shadowBlur  = 10
        ctx.shadowColor = "rgba(" + (r*255|0) + "," + (g*255|0) + "," + (b*255|0) + ",0.55)"
        ctx.lineCap     = "round"

        for (var i = 0; i < segments; i++) {
            var val = 0.0
            for (var j = 0; j < group; j++) {
                var idx = i * group + j
                if (idx < bars.length) val = Math.max(val, bars[idx])
            }

            var center = (i / segments) * Math.PI * 2 - Math.PI / 2
            var radius = baseR + val * amp
            var alpha  = 0.45 + val * 0.40   // brightens with amplitude

            ctx.strokeStyle = "rgba(" + (r*255|0) + "," + (g*255|0) + "," + (b*255|0) + "," + alpha.toFixed(2) + ")"
            ctx.lineWidth   = 4 + val * 4     // 4–8px, thicker when louder

            ctx.beginPath()
            ctx.arc(cx, cy, radius, center - arcSpan / 2, center + arcSpan / 2)
            ctx.stroke()
        }
    }
}
