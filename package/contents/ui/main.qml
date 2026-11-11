import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    fullRepresentation: Item {
        Layout.minimumWidth: 210
        Layout.minimumHeight: 150
        Layout.preferredWidth: 480
        Layout.preferredHeight: 370

        // blurred wallpaper behind the translucent card
        WallpaperBlur {
            anchors.fill: parent
            blur: Plasmoid.configuration.backgroundBlurRadius
            radius: Plasmoid.configuration.cornerRadius
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
