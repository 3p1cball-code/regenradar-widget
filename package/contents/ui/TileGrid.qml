import QtQuick

/*
 * A slippy-map tile layer for a fixed view: no panning, the view is derived
 * from originX/originY/worldScale, which the parent computes from the region
 * it wants to show. "{z}/{x}/{y}" in urlTemplate are substituted per tile.
 */
Item {
    id: grid

    property real worldScale: 1      // pixels for the whole world at the current scale
    property real originX: 0
    property real originY: 0
    property int  zoom: 8
    property string urlTemplate: ""
    property real tileOpacity: 1.0

    property int loadedCount: 0
    readonly property int tileCount: cols * rows
    readonly property bool ready: urlTemplate !== "" && tileCount > 0 && loadedCount >= tileCount

    readonly property real tileSize: worldScale / Math.pow(2, zoom)
    readonly property int  side: Math.pow(2, zoom)
    readonly property int  x0: Math.floor((0 - originX) / tileSize)
    readonly property int  y0: Math.floor((0 - originY) / tileSize)
    readonly property int  cols: Math.max(0, Math.min(24, Math.floor((width  - originX) / tileSize) - x0 + 1))
    readonly property int  rows: Math.max(0, Math.min(24, Math.floor((height - originY) / tileSize) - y0 + 1))

    function markLoaded() { loadedCount = loadedCount + 1 }

    onUrlTemplateChanged: loadedCount = 0
    onZoomChanged: loadedCount = 0

    clip: true

    Repeater {
        model: grid.cols * grid.rows

        delegate: Image {
            required property int index

            readonly property int tx: grid.x0 + (index % grid.cols)
            readonly property int ty: grid.y0 + Math.floor(index / grid.cols)
            readonly property bool valid: ty >= 0 && ty < grid.side && grid.urlTemplate !== ""

            x: grid.originX + tx * grid.tileSize
            y: grid.originY + ty * grid.tileSize
            width: grid.tileSize + 1
            height: grid.tileSize + 1
            opacity: grid.tileOpacity
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            sourceSize.width: 256
            sourceSize.height: 256
            visible: valid

            source: valid ? grid.urlTemplate
                                .replace("{z}", grid.zoom)
                                .replace("{x}", ((tx % grid.side) + grid.side) % grid.side)
                                .replace("{y}", ty)
                          : ""

            onStatusChanged: if (status === Image.Ready || status === Image.Error) grid.markLoaded()
            Component.onCompleted: if (!valid || status === Image.Ready || status === Image.Error) grid.markLoaded()
        }
    }
}
