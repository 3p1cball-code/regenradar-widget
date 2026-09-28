import QtQuick
import "../code/geo.js" as Geo
import "../code/palette.js" as Palette

/*
 * The whole widget. Deliberately free of Plasma dependencies so it can also be
 * run standalone (see test/Preview.qml) - main.qml only feeds it configuration.
 *
 * No shader effects are used anywhere: translucency is done by flattening a
 * layer and setting its opacity, which behaves identically on GPU and software
 * rendering.
 */
Item {
    id: view

    // --- configuration (bound from Plasmoid.configuration in main.qml) ------
    property real bgOpacity: 0.62
    property int  forecastHours: 4
    property bool showTemps: true
    property bool showLegend: true
    property bool lightBasemap: false
    property real cornerRadius: 14
    property bool debugOverlay: false

    // View state. configZoom/configPan* come from the settings page; the live
    // values below are also written by panning and Ctrl+wheel, and every change
    // is reported through viewStateChanged() so main.qml can persist it.
    property real configZoom: 1.0
    property real configPanX: 0.0
    property real configPanY: 0.0

    property real zoomFactor: 1.0
    property real panX: 0.0
    property real panY: 0.0

    readonly property real minZoom: 0.5
    readonly property real maxZoom: 5.0

    signal viewStateChanged(real zoom, real px, real py)

    onConfigZoomChanged: zoomFactor = configZoom
    onConfigPanXChanged: panX = configPanX
    onConfigPanYChanged: panY = configPanY


    implicitWidth: 460
    implicitHeight: 360

    readonly property real ui: Math.max(0.82, Math.min(1.7, Math.min(width / 460, height / 360)))
    readonly property color ink: lightBasemap ? "#101014" : "#ffffff"
    // the map is inset just far enough that its square corners stay inside the
    // rounded card - that gives rounded corners without needing a mask shader
    readonly property int inset: Math.max(4, Math.round(cornerRadius * 0.32) + 1)

    readonly property string basemapUrl:
        "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/"
        + (lightBasemap ? "World_Light_Gray_Base" : "World_Dark_Gray_Base")
        + "/MapServer/tile/{z}/{y}/{x}"

    // --- data --------------------------------------------------------------
    DataSource {
        id: src
        forecastHours: view.forecastHours
    }

    property int selected: 0
    property bool followNow: true

    readonly property int frameCount: src.frames.length
    readonly property int nowIdx: src.nowIndex

    readonly property var frame: (src.frames.length > 0 && selected < src.frames.length)
                                 ? src.frames[selected] : null

    Connections {
        target: src
        function onFramesChanged() {
            if (src.frames.length === 0)
                return;
            view.selected = view.followNow ? src.nowIndex
                          : Math.max(0, Math.min(src.frames.length - 1, view.selected));
        }
    }

    function goTo(i) {
        selected = Math.max(0, Math.min(src.frames.length - 1, i));
        followNow = (selected === src.nowIndex);
    }

    // --- map projection ----------------------------------------------------
    readonly property real regionLonMin: 11.05
    readonly property real regionLonMax: 15.00
    readonly property real regionLatMin: 51.25
    readonly property real regionLatMax: 53.68

    readonly property real nxMin: Geo.lonToX(regionLonMin)
    readonly property real nxMax: Geo.lonToX(regionLonMax)
    readonly property real nyMin: Geo.latToY(regionLatMax)
    readonly property real nyMax: Geo.latToY(regionLatMin)

    readonly property real mapW: Math.max(1, width - 2 * inset)
    readonly property real mapH: Math.max(1, height - 2 * inset)

    readonly property real regionNw: Math.max(1e-9, nxMax - nxMin)
    readonly property real regionNh: Math.max(1e-9, nyMax - nyMin)
    readonly property real regionCx: (nxMin + nxMax) / 2
    readonly property real regionCy: (nyMin + nyMax) / 2

    // zoom 1 fits Berlin + Brandenburg; pan is measured in region widths
    readonly property real fitScale: Math.min(mapW / regionNw, mapH / regionNh)
    readonly property real worldScale: fitScale * zoomFactor
    readonly property real centerNx: regionCx + panX * regionNw
    readonly property real centerNy: regionCy + panY * regionNh

    // origins are relative to the inner map area
    readonly property real originX: mapW / 2 - centerNx * worldScale
    readonly property real originY: mapH / 2 - centerNy * worldScale
    readonly property int  zoom: Math.max(5, Math.min(12, Math.ceil(Math.log(worldScale / 256) / Math.LN2)))

    function clampPan() {
        // never let the region wander entirely out of sight
        var m = 0.5 * Math.max(0, 1 - 1 / zoomFactor) + 0.35;
        panX = Math.max(-m, Math.min(m, panX));
        panY = Math.max(-m, Math.min(m, panY));
    }

    // cx/cy are map-local pixels to keep fixed while zooming (the cursor)
    function setZoom(z, cx, cy) {
        var nz = Math.max(minZoom, Math.min(maxZoom, z));
        if (Math.abs(nz - zoomFactor) < 1e-6)
            return;
        if (cx !== undefined) {
            var pNx = (cx - originX) / worldScale;
            var pNy = (cy - originY) / worldScale;
            var newScale = fitScale * nz;
            panX = (pNx + (mapW / 2 - cx) / newScale - regionCx) / regionNw;
            panY = (pNy + (mapH / 2 - cy) / newScale - regionCy) / regionNh;
        }
        zoomFactor = nz;
        clampPan();
        viewStateChanged(zoomFactor, panX, panY);
    }

    // position inside the inner map area
    function sx(lon) { return originX + Geo.lonToX(lon) * worldScale }
    function sy(lat) { return originY + Geo.latToY(lat) * worldScale }

    // --- the exact area on screen, as an EPSG:3857 bbox for the WMS --------
    // Web-Mercator metres are linear in normalised world coordinates, so this
    // needs no trigonometry - and it makes the radar align with the basemap
    // pixel for pixel.
    readonly property real earthCircumference: 40075016.6855785

    function currentBbox() {
        if (worldScale <= 0)
            return "";
        var l = (0 - originX) / worldScale;
        var r = (mapW - originX) / worldScale;
        var t = (0 - originY) / worldScale;
        var b = (mapH - originY) / worldScale;
        var C = earthCircumference;
        return ((l - 0.5) * C).toFixed(1) + "," + ((0.5 - b) * C).toFixed(1) + ","
             + ((r - 0.5) * C).toFixed(1) + "," + ((0.5 - t) * C).toFixed(1);
    }

    // settled request geometry - resizing must not hammer the DWD service
    property string reqBbox: ""
    property int reqW: 0
    property int reqH: 0

    function settleGeometry() {
        reqW = Math.max(64, Math.min(1400, Math.round(mapW)));
        reqH = Math.max(64, Math.min(1400, Math.round(mapH)));
        reqBbox = currentBbox();
    }

    onMapWChanged: geomSettle.restart()
    onMapHChanged: geomSettle.restart()
    onWorldScaleChanged: geomSettle.restart()
    onOriginXChanged: geomSettle.restart()
    onOriginYChanged: geomSettle.restart()
    Component.onCompleted: {
        zoomFactor = configZoom;
        panX = configPanX;
        panY = configPanY;
        geomSettle.restart();
    }

    Timer {
        id: geomSettle
        interval: 400
        onTriggered: view.settleGeometry()
    }

    readonly property bool frameIsRadar: frame && (frame.kind === "radar" || frame.kind === "nowcast")

    readonly property string radarUrl:
        (frameIsRadar && reqW > 0 && reqBbox !== "")
        ? src.radarUrl(frame.iso, reqW, reqH, reqBbox) : ""

    // --- labels ------------------------------------------------------------
    function two(n) { return (n < 10 ? "0" : "") + n }

    function clockOf(t) {
        var d = new Date(t * 1000);
        return d.getHours() + ":" + two(d.getMinutes());
    }

    function deltaLabel(f) {
        if (!f)
            return "";
        if (selected === src.nowIndex)
            return "JETZT";
        var d = Math.round((f.time - src.radarLatest) / 60);
        var a = Math.abs(d);
        var txt = a < 60 ? (a + " MIN") : (Math.floor(a / 60) + ":" + two(a % 60) + " STD");
        var tag = f.kind === "nowcast" ? "  ·  PROGNOSE"
                : f.kind === "forecast" ? "  ·  MODELL" : "";
        return (d < 0 ? "−" : "+") + txt + tag;
    }

    readonly property bool frameIsFuture: frame && frame.kind !== "radar"

    // =======================================================================
    //  card + basemap, flattened so the translucency is uniform
    // =======================================================================
    Item {
        id: card
        anchors.fill: parent
        layer.enabled: true
        opacity: view.bgOpacity

        Rectangle {
            anchors.fill: parent
            radius: view.cornerRadius
            color: view.lightBasemap ? "#f2f2f0" : "#000000"
        }

        Item {
            anchors.fill: parent
            anchors.margins: view.inset
            clip: true

            TileGrid {
                id: basemap
                anchors.fill: parent
                worldScale: view.worldScale
                originX: view.originX
                originY: view.originY
                zoom: view.zoom
                urlTemplate: view.basemapUrl
            }
        }
    }

    // =======================================================================
    //  precipitation, kept more solid than the map underneath
    // =======================================================================
    Item {
        id: rain
        anchors.fill: parent
        anchors.margins: view.inset
        clip: true
        layer.enabled: true
        opacity: Math.min(1.0, view.bgOpacity + 0.32)

        RadarLayer {
            id: radarLayer
            anchors.fill: parent
            url: view.radarUrl
            opacity: view.frameIsRadar ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        ForecastLayer {
            anchors.fill: parent
            worldScale: view.worldScale
            originX: view.originX
            originY: view.originY
            gridCols: src.gridCols
            gridRows: src.gridRows
            gridLonMin: src.gridLonMin
            gridLonMax: src.gridLonMax
            gridLatMin: src.gridLatMin
            gridLatMax: src.gridLatMax
            values: (view.frame && view.frame.kind === "forecast"
                     && view.frame.step < src.forecastGrids.length)
                    ? src.forecastGrids[view.frame.step] : []
            opacity: (view.frame && view.frame.kind === "forecast") ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    // --- scrims, so labels stay readable over bright rain -------------------
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: view.inset
        height: 62 * view.ui
        gradient: Gradient {
            GradientStop { position: 0.0; color: view.lightBasemap ? Qt.rgba(1, 1, 1, 0.68) : Qt.rgba(0, 0, 0, 0.62) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.margins: view.inset
        height: 74 * view.ui
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: view.lightBasemap ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(0, 0, 0, 0.68) }
        }
    }

    // hairline frame
    Rectangle {
        anchors.fill: parent
        radius: view.cornerRadius
        color: "transparent"
        border.width: 1
        border.color: view.lightBasemap ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(1, 1, 1, 0.12)
    }

    // =======================================================================
    //  temperatures
    // =======================================================================
    Item {
        anchors.fill: parent
        anchors.margins: view.inset
        clip: true

    Repeater {
        model: view.showTemps ? src.cities : []

        delegate: Item {
            required property var modelData

            // temperature at the selected frame's time, not at "now"
            readonly property real temp: view.frame
                                         ? src.tempAt(modelData, view.frame.time) : NaN

            // zooming in spreads the towns out, so more of them fit
            readonly property real room: view.width * Math.min(2.0, view.zoomFactor)
            readonly property int maxRank: room < 270 ? 0
                                         : room < 350 ? 1
                                         : room < 520 ? 2 : 3
            visible: modelData.rank <= maxRank && !isNaN(temp)
            x: view.sx(modelData.lon)
            y: view.sy(modelData.lat)
            width: 0
            height: 0

            Rectangle {
                x: -2.5; y: -2.5
                width: 5; height: 5; radius: 2.5
                color: view.ink
                opacity: 0.9
                Rectangle {
                    anchors.centerIn: parent
                    width: 12; height: 12; radius: 6
                    color: "transparent"
                    border.width: 1
                    border.color: view.lightBasemap ? Qt.rgba(0, 0, 0, 0.25) : Qt.rgba(1, 1, 1, 0.25)
                }
            }

            Column {
                x: 10
                y: -9 * view.ui
                spacing: -2

                Text {
                    text: Math.round(temp) + "°"
                    color: view.ink
                    opacity: 0.95
                    font.pixelSize: Math.round(14 * view.ui)
                    font.weight: Font.Light
                }
                Text {
                    text: modelData.name.toUpperCase()
                    color: view.ink
                    opacity: 0.38
                    font.pixelSize: Math.round(7 * view.ui)
                    font.letterSpacing: 1.1
                    font.weight: Font.Medium
                    visible: view.height > 200
                }
            }
        }
    }
    }

    // =======================================================================
    //  header
    // =======================================================================
    Column {
        anchors { left: parent.left; top: parent.top
                  leftMargin: 13 * view.ui; topMargin: 11 * view.ui }
        spacing: 2

        Text {
            text: "REGENRADAR"
            color: view.ink
            opacity: 0.6
            font.pixelSize: Math.round(9.5 * view.ui)
            font.letterSpacing: 3.2
            font.weight: Font.Medium
        }
        Text {
            text: "BERLIN · BRANDENBURG"
            color: view.ink
            opacity: 0.3
            font.pixelSize: Math.round(7 * view.ui)
            font.letterSpacing: 1.6
            visible: view.width > 250
        }
    }

    Column {
        anchors { right: parent.right; top: parent.top
                  rightMargin: 13 * view.ui; topMargin: 8 * view.ui }
        spacing: 0

        Text {
            anchors.right: parent.right
            text: view.frame ? view.clockOf(view.frame.time) : "––:––"
            color: view.ink
            opacity: 0.95
            font.pixelSize: Math.round(23 * view.ui)
            font.weight: Font.Thin
        }
        Text {
            anchors.right: parent.right
            text: view.deltaLabel(view.frame)
            color: view.frameIsFuture ? (view.lightBasemap ? "#7b3fd0" : "#c194f5") : view.ink
            opacity: view.frameIsFuture ? 0.9 : 0.45
            font.pixelSize: Math.round(7.5 * view.ui)
            font.letterSpacing: 1.4
            font.weight: Font.Medium
        }
    }

    // =======================================================================
    //  legend
    // =======================================================================
    Row {
        id: legend
        visible: view.showLegend && view.width > 320 && view.height > 210
        anchors {
            left: parent.left
            leftMargin: 14 * view.ui
            bottom: controls.top
            bottomMargin: 5 * view.ui
        }
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "0,1"
            color: view.ink
            opacity: 0.35
            font.pixelSize: Math.round(6.5 * view.ui)
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: 28
                Rectangle {
                    required property int index
                    width: Math.round(2.4 * view.ui)
                    height: Math.round(3.5 * view.ui)
                    color: Palette.cssColor(Math.pow(index / 27, 2.0) * 22.0)
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "20 mm/h"
            color: view.ink
            opacity: 0.35
            font.pixelSize: Math.round(6.5 * view.ui)
        }
    }

    // =======================================================================
    //  the one control: time
    // =======================================================================
    Item {
        id: controls
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 7 * view.ui
            rightMargin: 7 * view.ui
            bottomMargin: 13 * view.ui
        }
        height: 22

        TimeScrubber {
            id: scrubber
            anchors.fill: parent
            count: src.frames.length
            index: view.selected
            nowIndex: src.nowIndex
            accent: hover.hovered ? 1.0 : 0.0
            Behavior on accent { NumberAnimation { duration: 180 } }
            onIndexRequested: (i) => view.goTo(i)
        }
    }

    Text {
        anchors { right: parent.right; bottom: parent.bottom
                  rightMargin: 13 * view.ui; bottomMargin: 3 }
        text: "DWD Radarkomposit RV · ICON-D2 · Esri/OSM"
        color: view.ink
        opacity: 0.17
        font.pixelSize: Math.round(6 * view.ui)
        visible: view.width > 330
    }

    // status while the first fetch is running
    Text {
        anchors.centerIn: parent
        visible: src.frames.length === 0
        text: src.lastError === "" ? "LADE RADARDATEN …" : ("OFFLINE · " + src.lastError)
        color: view.ink
        opacity: 0.4
        font.pixelSize: Math.round(9 * view.ui)
        font.letterSpacing: 2
    }

    // developer aid; never shown in normal use
    Text {
        visible: view.debugOverlay
        anchors { left: parent.left; bottom: controls.top; leftMargin: 14; bottomMargin: 26 }
        color: "#7CFF9A"
        font.pixelSize: 10
        font.family: "monospace"
        text: "radarLatest=" + src.radarLatest
              + "  frames=" + src.frames.length
              + "  now=" + src.nowIndex + " sel=" + view.selected
              + "\nerr=" + (src.lastError === "" ? "-" : src.lastError)
              + "\nreq=" + view.reqW + "x" + view.reqH + " bbox=" + view.reqBbox
              + "\nstats=" + radarLayer.stats
    }

    // =======================================================================
    //  interaction
    // =======================================================================
    HoverHandler { id: hover }

    // Drag anywhere on the map to pan. Kept clear of the time scrubber, and
    // deliberately without any visible chrome of its own.
    Item {
        id: panSurface
        anchors.fill: parent
        anchors.margins: view.inset
        anchors.bottomMargin: view.inset + controls.height + 14 * view.ui

        HoverHandler {
            cursorShape: panner.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        DragHandler {
            id: panner
            target: null
            property real startX: 0
            property real startY: 0

            onActiveChanged: {
                if (active) {
                    startX = view.panX;
                    startY = view.panY;
                } else {
                    view.clampPan();
                    view.viewStateChanged(view.zoomFactor, view.panX, view.panY);
                }
            }
            onActiveTranslationChanged: {
                if (!active)
                    return;
                view.panX = startX - activeTranslation.x / (view.worldScale * view.regionNw);
                view.panY = startY - activeTranslation.y / (view.worldScale * view.regionNh);
                view.clampPan();
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (ev) => {
            if (ev.modifiers & Qt.ControlModifier) {
                view.setZoom(view.zoomFactor * (ev.angleDelta.y > 0 ? 1.15 : 1 / 1.15),
                             ev.x - view.inset, ev.y - view.inset);
            } else if (ev.angleDelta.y > 0) {
                view.goTo(view.selected + 1);
            } else if (ev.angleDelta.y < 0) {
                view.goTo(view.selected - 1);
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onDoubleTapped: view.goTo(src.nowIndex)
    }
}
