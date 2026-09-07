import QtQuick
import "../package/contents/ui" as W

Item {
    id: root
    width: 1000; height: 700

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2a2438" }
            GradientStop { position: 1.0; color: "#171520" }
        }
    }

    Grid {
        columns: 2
        spacing: 16
        x: 16; y: 16
        Repeater {
            id: rep
            model: 4
            W.RadarView {
                width: 476
                height: 326
                forecastHours: 5
            }
        }
    }

    // offsets from "now": -1h, now, +1h (radar nowcast), +3h30 (ICON-D2)
    property var offsets: [-6, 0, 6, 21]

    Timer {
        interval: 9000
        running: true
        onTriggered: {
            for (var i = 0; i < rep.count; ++i) {
                var v = rep.itemAt(i);
                v.followNow = false;
                v.selected = Math.max(0, Math.min(v.frameCount - 1, v.nowIdx + root.offsets[i]));
            }
        }
    }
}
