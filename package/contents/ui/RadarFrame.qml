import QtQuick
import "../code/palette.js" as Palette

/*
 * One DWD radar composite, recoloured on the fly.
 *
 * The WMS delivers 15 fixed classes on DWD's green/yellow/red scale. We draw
 * it 1:1 (it is requested at exactly this canvas size, so nothing resamples
 * the class colours), read the pixels back, and repaint the field in our own
 * blue-to-purple ramp - which keeps the widget monochrome apart from the rain.
 *
 * Repainting is done with run-length-encoded fillRect spans rather than
 * putImageData, which is not honoured by every Qt Quick render backend.
 */
Canvas {
    id: frame

    property string url: ""
    property int blockSize: 3
    property bool ready: false
    property string stats: ""    // diagnostics for the debug overlay

    renderTarget: Canvas.Image
    renderStrategy: Canvas.Immediate
    antialiasing: false

    property var _classOf: null

    Component.onCompleted: {
        _classOf = Palette.makeClassLookup();
        if (url !== "")
            load();
    }

    property int _attempts: 0

    function load() {
        ready = false;
        retry.stop();
        if (url === "") {
            requestPaint();
            return;
        }
        if (isImageLoaded(url)) {
            requestPaint();
        } else {
            loadImage(url);
            retry.restart();
        }
    }

    // Canvas offers no load-error signal, and the DWD service does time out
    // now and then, so re-ask for anything that has not arrived.
    Timer {
        id: retry
        interval: 6000
        repeat: false
        onTriggered: {
            if (frame.url === "" || frame.isImageLoaded(frame.url))
                return;
            if (frame._attempts < 3) {
                frame._attempts = frame._attempts + 1;
                frame.unloadImage(frame.url);
                frame.loadImage(frame.url);
                retry.restart();
            } else {
                frame.ready = true;   // give up; let the cross-fade proceed
            }
        }
    }

    onUrlChanged: { _attempts = 0; load(); }
    // Canvas has no load-error signal; RadarLayer's timeout covers stalls
    onImageLoaded: if (url !== "" && isImageLoaded(url)) { retry.stop(); requestPaint(); }
    onPainted: ready = true

    onPaint: {
        var ctx = getContext("2d");
        var W = Math.floor(width), H = Math.floor(height);
        if (W <= 0 || H <= 0)
            return;
        ctx.clearRect(0, 0, W, H);
        if (url === "" || !isImageLoaded(url) || !_classOf)
            return;

        // draw once only to read the classes back out
        ctx.drawImage(url, 0, 0, W, H);
        var d = ctx.getImageData(0, 0, W, H).data;
        ctx.clearRect(0, 0, W, H);

        var cls = _classOf;
        var css = Palette.CLASS_CSS;
        var S = Math.max(1, blockSize);
        var runs = 0;
        var t0 = Date.now();

        for (var y = 0; y < H; y += S) {
            var row = y * W * 4;
            var x = 0;
            while (x < W) {
                var o = row + x * 4;
                var c = cls(d[o], d[o + 1], d[o + 2], d[o + 3]);
                var x0 = x;
                x += S;
                while (x < W) {
                    var o2 = row + x * 4;
                    if (cls(d[o2], d[o2 + 1], d[o2 + 2], d[o2 + 3]) !== c)
                        break;
                    x += S;
                }
                if (c >= 0) {
                    ctx.fillStyle = css[c];
                    ctx.fillRect(x0, y, Math.min(x, W) - x0, Math.min(S, H - y));
                    ++runs;
                }
            }
        }
        stats = W + "x" + H + " spans=" + runs + " " + (Date.now() - t0) + "ms";
    }
}
