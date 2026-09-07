import QtQuick
import "../code/geo.js" as Geo
import "../code/palette.js" as Palette

/*
 * One ICON-D2 forecast step, drawn as a precipitation field in the same
 * classes and colours as the radar frames, so scrubbing past the end of the
 * radar nowcast does not change the visual language.
 *
 * The model grid is coarse (~30 km), so values are interpolated with a
 * Hermite (smoothstep) kernel - plain bilinear leaves diamond artefacts - and
 * then quantised into the DWD classes and emitted as run-length spans.
 */
Canvas {
    id: canvas

    property real worldScale: 1
    property real originX: 0
    property real originY: 0
    property int  blockSize: 3

    property var  values: []          // mm/h, row-major, row 0 = southernmost
    property int  gridCols: 11
    property int  gridRows: 10
    property real gridLonMin: 10.75
    property real gridLonMax: 15.35
    property real gridLatMin: 50.95
    property real gridLatMax: 53.95

    renderTarget: Canvas.Image
    renderStrategy: Canvas.Immediate
    antialiasing: false

    onValuesChanged: requestPaint()
    onWorldScaleChanged: requestPaint()
    onOriginXChanged: requestPaint()
    onOriginYChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        var W = Math.floor(width), H = Math.floor(height);
        if (W <= 0 || H <= 0)
            return;
        ctx.clearRect(0, 0, W, H);

        var g = values;
        if (!g || g.length < gridCols * gridRows || worldScale <= 0)
            return;

        var cols = gridCols, rows = gridRows;
        var dLon = (gridLonMax - gridLonMin) / (cols - 1);
        var dLat = (gridLatMax - gridLatMin) / (rows - 1);
        var S = Math.max(1, blockSize);
        var css = Palette.CLASS_CSS;

        // per-column fractional grid index, computed once
        var nx = Math.ceil(W / S);
        var ci = new Int32Array(nx), cfr = new Float64Array(nx), cok = new Uint8Array(nx);
        for (var xi = 0; xi < nx; ++xi) {
            var lon = Geo.xToLon((xi * S + 0.5 - originX) / worldScale);
            var fc = (lon - gridLonMin) / dLon;
            if (fc < 0 || fc > cols - 1) { cok[xi] = 0; continue; }
            var c0 = Math.min(cols - 2, Math.floor(fc));
            var f = fc - c0;
            ci[xi] = c0;
            cfr[xi] = f * f * (3.0 - 2.0 * f);
            cok[xi] = 1;
        }

        for (var y = 0; y < H; y += S) {
            var lat = Geo.yToLat((y + 0.5 - originY) / worldScale);
            var fr = (lat - gridLatMin) / dLat;
            if (fr < 0 || fr > rows - 1)
                continue;
            var r0 = Math.min(rows - 2, Math.floor(fr));
            var rf = fr - r0;
            rf = rf * rf * (3.0 - 2.0 * rf);
            var rowA = r0 * cols, rowB = (r0 + 1) * cols;

            var xi2 = 0;
            while (xi2 < nx) {
                var k = classAt(g, rowA, rowB, ci, cfr, cok, rf, xi2);
                var xStart = xi2;
                ++xi2;
                while (xi2 < nx
                       && classAt(g, rowA, rowB, ci, cfr, cok, rf, xi2) === k)
                    ++xi2;
                if (k >= 0) {
                    ctx.fillStyle = css[k];
                    var px = xStart * S;
                    ctx.fillRect(px, y, Math.min(xi2 * S, W) - px, Math.min(S, H - y));
                }
            }
        }
    }

    function classAt(g, rowA, rowB, ci, cfr, cok, rf, xi) {
        if (!cok[xi])
            return -1;
        var c = ci[xi], cf = cfr[xi];
        var v00 = g[rowA + c], v10 = g[rowA + c + 1];
        var v01 = g[rowB + c], v11 = g[rowB + c + 1];
        var top = v00 + (v10 - v00) * cf;
        var bot = v01 + (v11 - v01) * cf;
        return Palette.classOf(top + (bot - top) * rf);
    }
}
