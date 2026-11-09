// SeekBar.qml — Seek unificado (Volume + now-playing MPD).
// Línea fina + perilla redonda, drag + wheel. El dueño calcula `ratio` y resuelve
// el seek; el componente solo reporta ratios y congela animaciones en drag.
import QtQuick
import "../state"

Item {
    id: root

    implicitHeight: 20

    property real ratio: 0
    property bool animations: false
    property color activeColor: Style.primary
    property color trackColor: Style.surface_container_highest
    // tickMode: el ratio lo mueve un timer (1Hz MPD/MPRIS) — sin Behavior
    // para no correr una animación perpetua; el salto de 1s no se nota.
    property bool tickMode: false
    readonly property bool seeking: _seeking

    property bool _seeking: false

    signal seekAt(real ratio01)
    signal wheelMoved(int direction)

    function ratioAt(mx) {
        var w = trackBg.width
        if (w <= 0) return 0
        return Math.max(0, Math.min(1, (mx - trackBg.x) / w))
    }

    Rectangle {
        id: trackBg
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right; anchors.rightMargin: 8
        height: 4; radius: 2
        color: root.trackColor
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: trackBg.left
        height: 4; radius: 2
        width: trackBg.width * Math.max(0, Math.min(1, root.ratio))
        color: root.activeColor
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: trackBg.x + trackBg.width * Math.max(0, Math.min(1, root.ratio)) - width / 2
        width: 12; height: 12; radius: 6
        color: root.activeColor
    }

    Mouse {
        anchors.fill: parent
        preventStealing: true
        onPressed: (m) => {
            root._seeking = true
            root.seekAt(root.ratioAt(m.x))
        }
        onPositionChanged: (m) => { if (pressed) root.seekAt(root.ratioAt(m.x)) }
        onReleased: { root.seekAt(root.ratioAt(mouseX)); _releaseTimer.restart() }
        onWheel: (w) => root.wheelMoved(w.angleDelta.y > 0 ? 1 : -1)
        Timer {
            id: _releaseTimer
            interval: 1100
            onTriggered: root._seeking = false
        }
    }
}
