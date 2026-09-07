import QtQuick
import "../package/contents/ui" as W

/*
 * Size / variant matrix, used to produce doc/preview.png.
 * Set WALLPAPER to a local image path to preview over a real desktop picture.
 */
Item {
    width: 1060; height: 620

    readonly property string wallpaper: ""   // e.g. "file:///path/to/wallpaper.jpg"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#38405c" }
            GradientStop { position: 0.5; color: "#2b3047" }
            GradientStop { position: 1.0; color: "#14161f" }
        }
    }
    Image {
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: parent.wallpaper
        visible: parent.wallpaper !== "" && status === Image.Ready
    }

    W.RadarView { x: 20;  y: 20;  width: 480; height: 384 }
    W.RadarView { x: 20;  y: 430; width: 300; height: 170 }
    W.RadarView { x: 530; y: 20;  width: 480; height: 384; lightBasemap: true }
    W.RadarView { x: 530; y: 430; width: 240; height: 170; configZoom: 2.2 }
    W.RadarView { x: 790; y: 430; width: 220; height: 170; bgOpacity: 0.38 }
}
