import QtQuick
import "../package/contents/ui" as W

Item {
    width: 1000; height: 700
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2a2438" }
            GradientStop { position: 1.0; color: "#171520" }
        }
    }

    Grid {
        columns: 2; spacing: 16; x: 16; y: 16
        // zoomed out, whole of eastern Germany
        W.RadarView { width: 476; height: 326; configZoom: 0.6 }
        // default
        W.RadarView { width: 476; height: 326; configZoom: 1.0 }
        // zoomed on Berlin
        W.RadarView { width: 476; height: 326; configZoom: 2.5 }
        // zoomed and panned north-west
        W.RadarView { width: 476; height: 326; configZoom: 2.5; configPanX: -0.30; configPanY: -0.22 }
    }
}
