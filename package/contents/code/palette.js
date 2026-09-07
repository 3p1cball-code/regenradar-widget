.pragma library

/*
 * One colour ramp for everything that falls from the sky, in mm/h:
 * light blue -> blue -> indigo -> violet -> purple -> magenta.
 * Both the DWD radar frames and the ICON-D2 forecast field are recoloured
 * through this, so the widget only ever shows these hues.
 */
var STOPS = [
    [0.00,  150, 222, 252,   0],
    [0.10,  145, 220, 252, 125],
    [0.25,  112, 198, 250, 166],
    [0.60,   76, 162, 244, 197],
    [1.50,   48, 110, 232, 219],
    [3.00,   40,  72, 214, 234],
    [6.00,   70,  50, 205, 240],
    [12.0,  112,  45, 198, 245],
    [25.0,  150,  42, 192, 249],
    [50.0,  188,  40, 180, 251],
    [100.0, 218,  48, 158, 253],
    [200.0, 242,  86, 152, 255]
];

// Returns [r, g, b, a], a in 0..255.
function rgba(v) {
    if (!(v > 0.02))
        return [0, 0, 0, 0];
    var last = STOPS[STOPS.length - 1];
    if (v >= last[0])
        return [last[1], last[2], last[3], last[4]];
    for (var i = 1; i < STOPS.length; ++i) {
        if (v <= STOPS[i][0]) {
            var a = STOPS[i - 1], b = STOPS[i];
            var t = (v - a[0]) / (b[0] - a[0]);
            t = t * t * (3.0 - 2.0 * t);
            return [Math.round(a[1] + (b[1] - a[1]) * t),
                    Math.round(a[2] + (b[2] - a[2]) * t),
                    Math.round(a[3] + (b[3] - a[3]) * t),
                    Math.round(a[4] + (b[4] - a[4]) * t)];
        }
    }
    return [0, 0, 0, 0];
}

function cssColor(v) {
    var c = rgba(v);
    return Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, c[3] / 255);
}

/*
 * DWD renders the RV composite in 15 fixed classes. Taken from the service's
 * own GetLegendGraphic (format=application/json); the value is the
 * representative rain rate of each class in mm/h.
 */
var DWD_CLASSES = [
    [ 51, 255, 255,   0.14],   // [0.1 - 0.2)
    [ 26, 204, 154,   0.28],   // [0.2 - 0.4)
    [  1, 153,  52,   0.63],   // [0.4 - 1.0)
    [ 77, 179,  27,   1.40],   // [1.0 - 2.0)
    [153, 204,   1,   2.45],   // [2.0 - 3.0)
    [204, 230,   1,   3.90],   // [3.0 - 5.0)
    [255, 255,   1,   6.10],   // [5.0 - 7.5)
    [255, 196,   1,   8.70],   // [7.5 - 10)
    [255, 137,   1,  12.20],   // [10 - 15)
    [255,  69,   1,  21.00],   // [15 - 30)
    [254,   0,   0,  36.70],   // [30 - 45)
    [229,   0,  76,  58.00],   // [45 - 75)
    [204,   0, 152,  86.00],   // [75 - 100)
    [102,   0, 203, 122.00],   // [100 - 150)
    [  0,   0, 254, 180.00]    // >= 150
];

/*
 * Lower bound of each DWD class, in mm/h - the forecast field is quantised
 * into exactly the same classes so radar and model frames look alike.
 */
var CLASS_BOUNDS = [0.1, 0.2, 0.4, 1.0, 2.0, 3.0, 5.0, 7.5, 10.0,
                    15.0, 30.0, 45.0, 75.0, 100.0, 150.0];

// CSS colour string per class, taken from the ramp above.
var CLASS_CSS = (function () {
    var out = [];
    for (var i = 0; i < DWD_CLASSES.length; ++i) {
        var c = rgba(DWD_CLASSES[i][3]);
        out.push("rgba(" + c[0] + "," + c[1] + "," + c[2] + ","
                 + (c[3] / 255).toFixed(3) + ")");
    }
    return out;
})();

// mm/h -> class index, or -1 below the lowest class.
function classOf(v) {
    if (!(v >= CLASS_BOUNDS[0]))
        return -1;
    for (var i = CLASS_BOUNDS.length - 1; i >= 0; --i)
        if (v >= CLASS_BOUNDS[i])
            return i;
    return -1;
}

/*
 * Colour -> our colour, memoised. DWD's PNGs use exactly the class colours,
 * so this is a handful of lookups per frame; anything unexpected (the grey
 * "Keine Daten" fill, stray edge pixels) falls back to nearest class, and
 * near-transparent pixels are dropped.
 */
function makeClassLookup() {
    var cache = {};

    // r,g,b,a of a DWD pixel -> our class index, or -1 for "nothing to draw"
    return function (r, g, b, a) {
        // DWD paints every precipitation class fully opaque; the grey
        // "Keine Daten" fill and the magenta domain outline are not
        if (a < 250)
            return -1;
        var key = (r << 16) | (g << 8) | b;
        var hit = cache[key];
        if (hit !== undefined)
            return hit;

        var best = -1, bestD = 1e12;
        for (var i = 0; i < DWD_CLASSES.length; ++i) {
            var c = DWD_CLASSES[i];
            var dr = r - c[0], dg = g - c[1], db = b - c[2];
            var d = dr * dr + dg * dg + db * db;
            if (d < bestD) { bestD = d; best = i; }
        }
        // demand an (almost) exact class colour, so antialiased edges of
        // DWD's own annotations never turn into fake downpours
        var out = (bestD > 400) ? -1 : best;
        cache[key] = out;
        return out;
    };
}
