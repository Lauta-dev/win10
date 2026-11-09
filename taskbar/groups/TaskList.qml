// TaskList.qml — Estilo Windows 10: [pineados][abiertos no pineados]

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../state"
import "../../components"

Item {
    id: root
    clip: true

    // Refresco periódico de la lista (cada 1000 ms).
    property int _refreshTick: 0
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root._refreshTick++
    }

    ListView {
        id: listView
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        orientation: ListView.Horizontal
        spacing: 2
        clip: false
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds

        // Modelo: pineados primero, luego abiertos no pineados
        model: (function() {
            var _tick = root._refreshTick
            var pinned = TaskbarState.pinnedApps
            var open = OpenAppsState.appIds
            var pinnedSet = {}
            for (var i = 0; i < pinned.length; i++) pinnedSet[pinned[i]] = true
            var result = pinned.slice()
            for (var i = 0; i < open.length; i++) {
                if (!pinnedSet[open[i]]) result.push(open[i])
            }
            return result
        })()

        delegate: TaskButton {
            id: taskButton

            required property string modelData
            required property int    index

            appId: modelData
            isPinned: TaskbarState.isPinned(modelData)
            height: listView.height
        }

        property real targetX: 0
        onTargetXChanged: contentX = targetX

        Mouse {
            anchors.fill: parent
            hoverEnabled: false
            acceptedButtons: Qt.NoButton
            propagateComposedEvents: true
            onWheel: (wheel) => {
                var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
                var maxX  = Math.max(0, listView.contentWidth - listView.width)
                listView.targetX = Math.max(0, Math.min(listView.targetX - delta * 0.5, maxX))
            }
        }
    }
}
