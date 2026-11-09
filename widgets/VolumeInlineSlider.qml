// VolumeInlineSlider.qml — Slider mínimo inline para la taskbar:
// línea fina + perilla redonda (------------o). Click/drag + rueda.
import QtQuick
import Quickshell
import "../state"
import "../components"

Item {
    id: root

    property real value: 0 // 0..100
    property bool dimmed: false // ej: muteado

    signal changeRequested(real newValue)

    readonly property color _active: root.dimmed ? Style.outline : Style.primary

    // Margen lateral de la pista.
    readonly property real _pad: 10

    // Pista
    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.leftMargin: root._pad
        anchors.right: parent.right; anchors.rightMargin: root._pad
        height: 4; radius: 2
        color: Style.surface_container_highest
    }

    // Relleno
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: track.left
        height: track.height; radius: track.radius
        width: track.width * Math.max(0, Math.min(100, root.value)) / 100
        color: root._active
    }

    // Perilla
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: track.x + track.width * Math.max(0, Math.min(100, root.value)) / 100 - width / 2
        width: 12; height: 12; radius: 6
        color: root._active
    }

    Mouse {
        anchors.fill: parent
        preventStealing: true
        onPressed:         (m) => apply(m.x)
        onPositionChanged: (m) => { if (pressed) apply(m.x) }
        onWheel: (w) => {
            var v = Math.max(0, Math.min(100, root.value + (w.angleDelta.y > 0 ? 5 : -5)))
            root.changeRequested(v)
        }
        function apply(mx) {
            var v = Math.round(Math.max(0, Math.min(mx - track.x, track.width)) / track.width * 100)
            root.changeRequested(v)
        }
    }
}
