import QtQuick
import "../package/contents/ui" as W

Item {
    id: root
    width: 980
    height: 660

    // stand-in wallpaper so the translucency is judgeable
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#2a2438" }
            GradientStop { position: 0.55; color: "#3d3550" }
            GradientStop { position: 1.0; color: "#171520" }
        }
    }
    Repeater {
        model: 9
        Rectangle {
            required property int index
            x: 40 + index * 105
            y: 60 + (index % 3) * 170
            width: 90; height: 90; radius: 45
            color: "#ffffff"
            opacity: 0.05
        }
    }

    W.RadarView {
        id: big
        x: 40
        y: 40
        width: 560
        height: 420
    }

    W.RadarView {
        id: small
        x: 640
        y: 40
        width: 300
        height: 230
    }

    W.RadarView {
        id: tiny
        x: 640
        y: 300
        width: 230
        height: 165
    }
}
