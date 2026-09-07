import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_backgroundOpacity: opacitySlider.value
    property alias cfg_cornerRadius: radiusSpin.value
    property alias cfg_forecastHours: forecastSpin.value
    property alias cfg_showTemperatures: tempsCheck.checked
    property alias cfg_showLegend: legendCheck.checked
    property alias cfg_lightBasemap: lightCheck.checked
    property real cfg_zoomFactor: 1.0
    property real cfg_panX: 0.0
    property real cfg_panY: 0.0

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        RowLayout {
            Kirigami.FormData.label: i18n("Transparenz:")
            QQC2.Slider {
                id: opacitySlider
                from: 0.2
                to: 1.0
                stepSize: 0.02
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            }
            QQC2.Label {
                text: Math.round(opacitySlider.value * 100) + " %"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Zoom:")
            QQC2.Slider {
                id: zoomSlider
                from: 0.5
                to: 5.0
                stepSize: 0.1
                value: page.cfg_zoomFactor
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                onMoved: page.cfg_zoomFactor = value
            }
            QQC2.Label {
                text: page.cfg_zoomFactor.toFixed(1) + " ×"
                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            }
        }

        QQC2.Button {
            text: i18n("Ansicht zentrieren")
            enabled: page.cfg_panX !== 0.0 || page.cfg_panY !== 0.0 || page.cfg_zoomFactor !== 1.0
            onClicked: {
                page.cfg_panX = 0.0;
                page.cfg_panY = 0.0;
                page.cfg_zoomFactor = 1.0;
            }
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 18
            wrapMode: Text.WordWrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: i18n("Im Widget: Strg + Mausrad zoomt, Ziehen verschiebt den Kartenausschnitt.")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: radiusSpin
            Kirigami.FormData.label: i18n("Eckenradius:")
            from: 0
            to: 40
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: forecastSpin
            Kirigami.FormData.label: i18n("Vorhersage:")
            from: 1
            to: 8
            textFromValue: (value) => i18np("%1 Stunde", "%1 Stunden", value)
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: tempsCheck
            Kirigami.FormData.label: i18n("Anzeigen:")
            text: i18n("Temperaturen")
        }
        QQC2.CheckBox {
            id: legendCheck
            text: i18n("Farbskala")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: lightCheck
            Kirigami.FormData.label: i18n("Karte:")
            text: i18n("Helle Variante")
        }
    }
}
