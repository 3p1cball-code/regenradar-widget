import QtQuick

/*
 * The widget's only control: drag to move through time. Past half is a solid
 * hairline, the forecast half is dotted.
 */
Item {
    id: bar

    property int count: 0
    property int index: 0
    property int nowIndex: 0
    property real accent: 1.0        // 0..1, fades the whole control in on hover

    signal indexRequested(int i)

    implicitHeight: 22

    readonly property real pad: 9
    readonly property real usable: Math.max(1, width - 2 * pad)

    function xFor(i) {
        return count > 1 ? pad + usable * (i / (count - 1)) : pad + usable / 2;
    }
    function indexAt(px) {
        if (count < 2)
            return 0;
        var t = Math.max(0, Math.min(1, (px - pad) / usable));
        return Math.round(t * (count - 1));
    }

    // past track
    Rectangle {
        x: bar.pad
        width: Math.max(0, bar.xFor(bar.nowIndex) - bar.pad)
        height: 1
        y: bar.height / 2
        color: "#ffffff"
        opacity: 0.20 + 0.22 * bar.accent
    }

    // forecast track, dotted
    Row {
        x: bar.xFor(bar.nowIndex)
        y: bar.height / 2
        spacing: 3
        Repeater {
            model: Math.max(0, Math.floor((bar.width - bar.pad - bar.xFor(bar.nowIndex)) / 5))
            Rectangle {
                width: 2; height: 1
                color: "#ffffff"
                opacity: 0.16 + 0.20 * bar.accent
            }
        }
    }

    // frame ticks
    Repeater {
        model: bar.count
        Rectangle {
            required property int index
            x: bar.xFor(index) - 0.5
            y: bar.height / 2 - 2
            width: 1
            height: 5
            color: "#ffffff"
            opacity: (0.07 + 0.13 * bar.accent) * (index === bar.nowIndex ? 3.0 : 1.0)
        }
    }

    // "now" marker
    Rectangle {
        x: bar.xFor(bar.nowIndex) - 0.5
        y: bar.height / 2 - 6
        width: 1
        height: 13
        color: "#ffffff"
        opacity: 0.30 + 0.35 * bar.accent
    }

    // handle
    Rectangle {
        id: handle
        width: 11
        height: 11
        radius: 5.5
        x: bar.xFor(bar.index) - width / 2
        y: bar.height / 2 - height / 2
        color: "#ffffff"
        opacity: 0.75 + 0.25 * bar.accent
        Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.centerIn: parent
            width: 3; height: 3; radius: 1.5
            color: "#000000"
            opacity: 0.55
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        preventStealing: true
        onPressed: (m) => bar.indexRequested(bar.indexAt(m.x))
        onPositionChanged: (m) => { if (pressed) bar.indexRequested(bar.indexAt(m.x)) }
    }
}
