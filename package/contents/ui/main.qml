import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    // the widget draws its own translucent background
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    fullRepresentation: RadarView {
        Layout.minimumWidth: 210
        Layout.minimumHeight: 150
        Layout.preferredWidth: 480
        Layout.preferredHeight: 370

        bgOpacity: Plasmoid.configuration.backgroundOpacity
        forecastHours: Plasmoid.configuration.forecastHours
        showTemps: Plasmoid.configuration.showTemperatures
        showLegend: Plasmoid.configuration.showLegend
        cornerRadius: Plasmoid.configuration.cornerRadius
        lightBasemap: Plasmoid.configuration.lightBasemap

        configZoom: Plasmoid.configuration.zoomFactor
        configPanX: Plasmoid.configuration.panX
        configPanY: Plasmoid.configuration.panY

        // panning and Ctrl+wheel change the view directly; persist it so the
        // widget comes back where it was left
        onViewStateChanged: (zoom, px, py) => {
            Plasmoid.configuration.zoomFactor = zoom;
            Plasmoid.configuration.panX = px;
            Plasmoid.configuration.panY = py;
        }
    }
}
