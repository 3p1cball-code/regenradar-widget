import QtQuick

/*
 * Everything the widget shows:
 *
 *   past .. +2 h : DWD "RV" radar composite (1x1 km, 5 min steps), analysis
 *                  and radar nowcast, via the DWD WMS at maps.dwd.de
 *   +2 h .. +N h : DWD ICON-D2 precipitation via Open-Meteo (2.2 km, 15 min)
 *   temperatures : Open-Meteo, a handful of cities in the region
 *
 * merged into one chronological "frames" timeline.
 */
QtObject {
    id: src

    property int forecastHours: 4        // total horizon, radar nowcast included

    readonly property string wmsBase: "https://maps.dwd.de/geoserver/dwd/wms"
    readonly property string radarLayer: "dwd:Radar_rv_product_1x1km_ger"
    readonly property int pastMinutes: 120
    readonly property int stepMinutes: 10
    readonly property int nowcastMinutes: 120   // the RV product's horizon

    // --- forecast grid geometry (a bit larger than the displayed region) ----
    readonly property real gridLonMin: 10.75
    readonly property real gridLonMax: 15.35
    readonly property real gridLatMin: 50.95
    readonly property real gridLatMax: 53.95
    readonly property int  gridCols: 11
    readonly property int  gridRows: 10

    // --- results -----------------------------------------------------------
    property double radarLatest: 0    // epoch seconds, aligned to 5 min
    property var forecastTimes: []
    property var forecastGrids: []
    property var cities: []

    property var frames: []           // [{ time, kind: radar|nowcast|forecast, iso, step }]
    property int nowIndex: 0

    property string lastError: ""

    readonly property var cityList: [
        { name: "Berlin",          lat: 52.520, lon: 13.405, rank: 0 },
        { name: "Cottbus",         lat: 51.757, lon: 14.329, rank: 1 },
        { name: "Neuruppin",       lat: 52.923, lon: 12.803, rank: 1 },
        { name: "Frankfurt (O.)",  lat: 52.348, lon: 14.551, rank: 2 },
        { name: "Wittenberge",     lat: 52.995, lon: 11.752, rank: 2 },
        { name: "Prenzlau",        lat: 53.316, lon: 13.863, rank: 3 },
        { name: "Potsdam",         lat: 52.396, lon: 13.059, rank: 3 },
        { name: "Elsterwerda",     lat: 51.461, lon: 13.520, rank: 3 }
    ]

    // -----------------------------------------------------------------------
    function isoOf(t) {
        return new Date(t * 1000).toISOString().replace(/\.\d{3}Z$/, "Z");
    }

    function radarUrl(iso, w, h, bbox) {
        return wmsBase
             + "?service=WMS&version=1.3.0&request=GetMap"
             + "&layers=" + encodeURIComponent(radarLayer)
             + "&styles=&crs=EPSG:3857&format=image/png&transparent=true"
             + "&width=" + w + "&height=" + h
             + "&bbox=" + bbox
             + "&time=" + encodeURIComponent(iso);
    }

    function get(url, onOk, onFail) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                try {
                    onOk(xhr);
                    src.lastError = "";
                    return;
                } catch (e) {
                    src.lastError = "" + e;
                }
            } else {
                src.lastError = "HTTP " + xhr.status;
            }
            if (onFail)
                onFail();
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // --- find the newest radar composite the service actually has -----------
    function probeLatest(t, tries) {
        var url = radarUrl(isoOf(t), 2, 2, "1230080,6665635,1669792,7109783");
        get(url, function(xhr) {
            var ct = ("" + xhr.getResponseHeader("Content-Type")).toLowerCase();
            if (ct.indexOf("xml") >= 0) {
                if (tries > 0)
                    probeLatest(t - 300, tries - 1);
                return;
            }
            src.radarLatest = t;
            src.rebuild();
        }, function() {
            if (tries > 0)
                probeLatest(t - 300, tries - 1);
        });
    }

    function refreshRadar() {
        var now = Date.now() / 1000;
        probeLatest(Math.floor((now - 300) / 300) * 300, 5);
    }

    // --- ICON-D2 beyond the radar nowcast ----------------------------------
    function forecastUrl() {
        var lats = [], lons = [];
        for (var r = 0; r < gridRows; ++r) {
            for (var c = 0; c < gridCols; ++c) {
                lats.push((gridLatMin + r * (gridLatMax - gridLatMin) / (gridRows - 1)).toFixed(3));
                lons.push((gridLonMin + c * (gridLonMax - gridLonMin) / (gridCols - 1)).toFixed(3));
            }
        }
        return "https://api.open-meteo.com/v1/forecast"
             + "?latitude=" + lats.join(",")
             + "&longitude=" + lons.join(",")
             + "&minutely_15=precipitation&models=icon_d2&timezone=UTC"
             + "&forecast_minutely_15=" + (forecastHours * 4 + 6);
    }

    function fetchForecast() {
        if (forecastHours * 60 <= nowcastMinutes) {
            forecastTimes = [];
            forecastGrids = [];
            rebuild();
            return;
        }
        get(forecastUrl(), function(xhr) {
            var d = JSON.parse(xhr.responseText);
            if (!Array.isArray(d))
                d = [d];
            var n = gridCols * gridRows;
            if (d.length < n)
                return;

            var times = [], first = d[0].minutely_15;
            for (var t = 0; t < first.time.length; ++t)
                times.push(Date.parse(first.time[t] + "Z") / 1000);

            var grids = [];
            for (var s = 0; s < times.length; ++s)
                grids.push(new Array(n).fill(0));

            for (var i = 0; i < d.length; ++i) {
                var id = (d[i].location_id !== undefined) ? d[i].location_id : 0;
                if (id >= n)
                    continue;
                var p = d[i].minutely_15.precipitation;
                for (var k = 0; k < times.length && k < p.length; ++k)
                    grids[k][id] = (p[k] || 0) * 4.0;   // mm/15min -> mm/h
            }
            src.forecastTimes = times;
            src.forecastGrids = grids;
            src.rebuild();
        });
    }

    // --- temperatures ------------------------------------------------------
    function fetchTemps() {
        var lats = [], lons = [];
        for (var i = 0; i < cityList.length; ++i) {
            lats.push(cityList[i].lat);
            lons.push(cityList[i].lon);
        }
        get("https://api.open-meteo.com/v1/forecast?latitude=" + lats.join(",")
            + "&longitude=" + lons.join(",")
            + "&current=temperature_2m&timezone=UTC", function(xhr) {
            var d = JSON.parse(xhr.responseText);
            if (!Array.isArray(d))
                d = [d];
            var out = [];
            for (var i = 0; i < cityList.length; ++i)
                out.push({ name: cityList[i].name, lat: cityList[i].lat,
                           lon: cityList[i].lon, rank: cityList[i].rank, temp: NaN });
            for (var j = 0; j < d.length; ++j) {
                var id = (d[j].location_id !== undefined) ? d[j].location_id : 0;
                if (id < out.length && d[j].current)
                    out[id].temp = d[j].current.temperature_2m;
            }
            src.cities = out;
        });
    }

    // --- timeline ----------------------------------------------------------
    function rebuild() {
        if (radarLatest <= 0)
            return;

        var list = [], t;
        var stepS = stepMinutes * 60;

        for (t = radarLatest - pastMinutes * 60; t < radarLatest; t += stepS)
            list.push({ time: t, kind: "radar", iso: isoOf(t), step: -1 });
        list.push({ time: radarLatest, kind: "radar", iso: isoOf(radarLatest), step: -1 });
        var now = list.length - 1;

        // never look further ahead than the user asked for
        var nowcastEnd = radarLatest + Math.min(nowcastMinutes, forecastHours * 60) * 60;
        for (t = radarLatest + stepS; t <= nowcastEnd; t += stepS)
            list.push({ time: t, kind: "nowcast", iso: isoOf(t), step: -1 });

        var horizon = radarLatest + forecastHours * 3600;
        for (var s = 0; s < forecastTimes.length; ++s) {
            var ft = forecastTimes[s];
            if (ft > nowcastEnd + 60 && ft <= horizon)
                list.push({ time: ft, kind: "forecast", iso: "", step: s });
        }

        // nowIndex first: assigning frames notifies listeners straight away
        nowIndex = now;
        frames = list;
    }

    onForecastHoursChanged: fetchForecast()

    // --- refresh timers ----------------------------------------------------
    property Timer radarTimer: Timer {
        interval: 5 * 60 * 1000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: src.refreshRadar()
    }
    property Timer forecastTimer: Timer {
        interval: 20 * 60 * 1000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: src.fetchForecast()
    }
    property Timer tempTimer: Timer {
        interval: 10 * 60 * 1000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: src.fetchTemps()
    }
}
