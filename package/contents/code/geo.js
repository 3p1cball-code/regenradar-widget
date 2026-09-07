.pragma library

// Web-Mercator helpers. All "world" coordinates are normalised to 0..1,
// so they are independent of the tile zoom level.

function lonToX(lon) {
    return (lon + 180.0) / 360.0;
}

function latToY(lat) {
    var s = Math.sin(lat * Math.PI / 180.0);
    if (s > 0.9999) s = 0.9999;
    if (s < -0.9999) s = -0.9999;
    return 0.5 - Math.log((1.0 + s) / (1.0 - s)) / (4.0 * Math.PI);
}

function xToLon(x) {
    return x * 360.0 - 180.0;
}

function yToLat(y) {
    var n = Math.PI * (1.0 - 2.0 * y);
    return 180.0 / Math.PI * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)));
}
