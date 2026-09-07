import QtQuick

/*
 * Two radar frames that cross-fade, so scrubbing never flashes an empty map
 * while the next composite is still being fetched and recoloured.
 */
Item {
    id: layer

    property string url: ""

    property bool showA: true
    property string urlA: ""
    property string urlB: ""
    readonly property string stats: showA ? a.stats : b.stats

    onUrlChanged: {
        if (url === "" || url === (showA ? urlA : urlB))
            return;
        if (showA)
            urlB = url;
        else
            urlA = url;
        swapTimeout.restart();
    }

    Timer {
        id: swapTimeout
        interval: 3000
        onTriggered: layer.showA = !layer.showA
    }

    RadarFrame {
        id: a
        anchors.fill: parent
        url: layer.urlA
        opacity: layer.showA ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
        onReadyChanged: if (ready && !layer.showA && layer.urlA === layer.url) {
            swapTimeout.stop();
            layer.showA = true;
        }
    }

    RadarFrame {
        id: b
        anchors.fill: parent
        url: layer.urlB
        opacity: layer.showA ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
        onReadyChanged: if (ready && layer.showA && layer.urlB === layer.url) {
            swapTimeout.stop();
            layer.showA = false;
        }
    }
}
