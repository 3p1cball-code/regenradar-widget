import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import QtQuick.Effects

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    property string wallpaperPath: ""

    Component.onCompleted: root.loadWallpaper()

    Plasma5Support.DataSource {
        id: wallpaperExec
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source);
            if (data["exit code"] === 0) {
                var p = data["stdout"].trim();
                if (p.length > 0 && p !== "null")
                    root.wallpaperPath = p;
            }
        }
    }

    function loadWallpaper() {
        var cid = Plasmoid.containment.id;
        var plugin = Plasmoid.containment.wallpaperPlugin || "org.kde.image";
        if (!cid)
            return;
        wallpaperExec.connectSource("kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group Containments --group " + cid +
                                    " --group Wallpaper --group " + plugin + " --group General --key Image");
    }

    fullRepresentation: Item {
        id: fullRoot
        Layout.minimumWidth: 210
        Layout.minimumHeight: 150
        Layout.preferredWidth: 480
        Layout.preferredHeight: 370

        Image {
            id: wallpaperImage
            anchors.fill: parent
            visible: false
            asynchronous: true
            cache: true
            source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
            fillMode: Image.PreserveAspectCrop
            sourceClipRect: {
                if (!sourceSize.width || !sourceSize.height)
                    return Qt.rect(0, 0, 0, 0);
                var s = Math.max(Screen.width / sourceSize.width, Screen.height / sourceSize.height);
                var p = fullRoot.mapToItem(null, 0, 0);
                var ox = (Screen.width - sourceSize.width * s) / 2;
                var oy = (Screen.height - sourceSize.height * s) / 2;
                return Qt.rect((p.x - ox) / s, (p.y - oy) / s, fullRoot.width / s, fullRoot.height / s);
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: wallpaperImage
            visible: root.wallpaperPath !== "" && Plasmoid.configuration.backgroundBlurRadius > 0.001
            blurEnabled: true
            blur: Plasmoid.configuration.backgroundBlurRadius
            blurMax: 64
            autoPaddingEnabled: false
        }

        RadarView {
            anchors.fill: parent
            bgOpacity: Plasmoid.configuration.backgroundOpacity
            forecastHours: Plasmoid.configuration.forecastHours
            showTemps: Plasmoid.configuration.showTemperatures
            showLegend: Plasmoid.configuration.showLegend
            cornerRadius: Plasmoid.configuration.cornerRadius
            lightBasemap: Plasmoid.configuration.lightBasemap

            configZoom: Plasmoid.configuration.zoomFactor
            configPanX: Plasmoid.configuration.panX
            configPanY: Plasmoid.configuration.panY

            onViewStateChanged: (zoom, px, py) => {
                Plasmoid.configuration.zoomFactor = zoom;
                Plasmoid.configuration.panX = px;
                Plasmoid.configuration.panY = py;
            }
        }
    }
}
