import QtQuick

// Contour arrondi tracé avec un dégradé 45° de couleurs qui défile.
// `palette` = liste de couleurs (hex strings, ex. wallust color*). Autonome,
// s'anime seulement quand visible.
Canvas {
    id: gb

    property var  palette:     []
    property real radius:      16
    property int  borderWidth: 2
    property real phase:       0

    onPhaseChanged:       requestPaint()
    onWidthChanged:       requestPaint()
    onHeightChanged:      requestPaint()
    onRadiusChanged:      requestPaint()
    onPaletteChanged:     requestPaint()
    onBorderWidthChanged: requestPaint()

    Timer {
        running:  gb.visible
        interval: 33; repeat: true
        onTriggered: gb.phase = (gb.phase + 0.006) % 1.0
    }

    function _rgb(h) {
        h = ("" + h).replace("#", "")
        if (h.length >= 6)
            return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]
        return [255, 255, 255]
    }
    function _rainbowAt(t) {
        var c = gb.palette, n = c.length
        if (n === 0) return "rgb(255,255,255)"
        if (n === 1) { var s = _rgb(c[0]); return "rgb(" + s[0] + "," + s[1] + "," + s[2] + ")" }
        var x = (((t % 1) + 1) % 1) * n
        var i = Math.floor(x) % n, j = (i + 1) % n, f = x - Math.floor(x)
        var a = _rgb(c[i]), b = _rgb(c[j])
        return "rgb(" + Math.round(a[0] + (b[0] - a[0]) * f) + ","
                      + Math.round(a[1] + (b[1] - a[1]) * f) + ","
                      + Math.round(a[2] + (b[2] - a[2]) * f) + ")"
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        var w = width, h = height, bw = gb.borderWidth
        var inset = bw / 2
        var rr = Math.max(0, gb.radius - inset)
        var x0 = inset, y0 = inset, x1 = w - inset, y1 = h - inset

        ctx.beginPath()
        ctx.moveTo(x0 + rr, y0)
        ctx.lineTo(x1 - rr, y0)
        ctx.arcTo(x1, y0, x1, y0 + rr, rr)
        ctx.lineTo(x1, y1 - rr)
        ctx.arcTo(x1, y1, x1 - rr, y1, rr)
        ctx.lineTo(x0 + rr, y1)
        ctx.arcTo(x0, y1, x0, y1 - rr, rr)
        ctx.lineTo(x0, y0 + rr)
        ctx.arcTo(x0, y0, x0 + rr, y0, rr)
        ctx.closePath()

        var grad = ctx.createLinearGradient(0, 0, (w + h) / 2, (w + h) / 2)  // 45°
        var steps = 20
        for (var k = 0; k <= steps; k++) {
            var p = k / steps
            grad.addColorStop(p, gb._rainbowAt(p + gb.phase))
        }
        ctx.strokeStyle = grad
        ctx.lineWidth   = bw
        ctx.stroke()
    }
}
